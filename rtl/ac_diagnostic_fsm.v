// ============================================================================
// TAS6424E-Q1 AC诊断状态机 (v6.0, 6态)
// 功能: 全局AC负载诊断 —— 测量高频扬声器的阻抗和相位
// 设计原则:
//   - 6态顺序FSM: IDLE→CH1_AC→CH2_AC→CH3_AC→CH4_AC→DONE
//   - 修复#1: 每阶段跳过非诊断通道 (ch_ac_active[i]==0 → next)
//   - 修复#7: 与DC FSM互斥 (ac_busy时dc不能启动)
//   - 由any_ch_ac触发, 完成后ch_ac_done[i]通知通道FSM
//   - AC诊断需要外部输入信号 (datasheet: 0-dBFS 19kHz)
// ============================================================================

module ac_diagnostic_fsm (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 触发/中止
    input  wire         any_ch_ac,          // 任意通道在CH_AC_DIAG_ENTRY → 触发
    input  wire         dc_fsm_busy,        // DC FSM正在运行 → 互斥等待 (修复#7)
    input  wire         ac_ldg_abort,       // 中止AC诊断
    // 通道AC激活状态
    input  wire [3:0]   ch_ac_active,       // ch_ac_active[0:3] 来自channel_fsm
    input  wire [3:0]   ch_diag_active,     // 用于互斥检查
    // 模拟前端测量输入
    input  wire [7:0]   ac_imp_ch0,         // CH1 阻抗测量值
    input  wire [7:0]   ac_imp_ch1,         // CH2 阻抗测量值
    input  wire [7:0]   ac_imp_ch2,         // CH3 阻抗测量值
    input  wire [7:0]   ac_imp_ch3,         // CH4 阻抗测量值
    input  wire [15:0]  ac_phase_val,       // 相位测量值 (16bit)
    input  wire [15:0]  ac_sti_val,         // 刺激值 (16bit)
    // 诊断控制
    input  wire [7:0]   ac_diag_ctrl1,      // 0x15: gain + enable
    input  wire [7:0]   ac_diag_ctrl2,      // 0x16: loopback + timing + current
    input  wire [23:0]  ac_timeout_val,     // 可配超时值 (~130ms per ch)
    // 诊断状态输出
    output reg  [2:0]   ac_diag_state,      // 当前FSM状态 (3bit)
    output wire         ac_fsm_busy,        // FSM正在运行 (=1时DC不能启动)
    // 完成信号 → 通道FSM
    output reg  [3:0]   ch_ac_done,         // ch_ac_done[i]=1 → 通道i AC诊断完成
    // AC诊断报告 → register_file (硬件写)
    output reg  [7:0]   ac_diag_rpt_ch1,    // 0x17
    output reg  [7:0]   ac_diag_rpt_ch2,    // 0x18
    output reg  [7:0]   ac_diag_rpt_ch3,    // 0x19
    output reg  [7:0]   ac_diag_rpt_ch4,    // 0x1A
    output reg  [7:0]   ac_phase_high,      // 0x1B
    output reg  [7:0]   ac_phase_low,       // 0x1C
    output reg  [7:0]   ac_sti_high,        // 0x1D
    output reg  [7:0]   ac_sti_low,         // 0x1E
    output reg          hw_wr_en,
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);

    // ========================================================================
    // 状态编码 (6态)
    // ========================================================================
    localparam AC_DIAG_IDLE = 3'd0;
    localparam CH1_AC       = 3'd1;
    localparam CH2_AC       = 3'd2;
    localparam CH3_AC       = 3'd3;
    localparam CH4_AC       = 3'd4;
    localparam AC_DONE      = 3'd5;

    // ========================================================================
    // 内部信号
    // ========================================================================
    reg [23:0] stage_timer;
    wire       stage_timer_done;
    reg  [7:0] rpt1_shadow, rpt2_shadow, rpt3_shadow, rpt4_shadow;
    reg [15:0] phase_shadow, sti_shadow;

    assign stage_timer_done = (stage_timer >= ac_timeout_val);
    assign ac_fsm_busy = (ac_diag_state != AC_DIAG_IDLE) && (ac_diag_state != AC_DONE);

    // ========================================================================
    // 时序逻辑: 状态机 + 计时器
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ac_diag_state   <= AC_DIAG_IDLE;
            stage_timer     <= 24'd0;
            ch_ac_done      <= 4'b0000;
            hw_wr_en        <= 1'b0;
            {rpt1_shadow, rpt2_shadow, rpt3_shadow, rpt4_shadow} <= 32'd0;
            phase_shadow <= 16'd0;
            sti_shadow   <= 16'd0;
        end else begin

            // ---- 中止处理 ----
            if (ac_ldg_abort && ac_fsm_busy) begin
                ac_diag_state <= AC_DIAG_IDLE;
                stage_timer   <= 24'd0;
                ch_ac_done    <= ch_ac_active;  // 通知所有等待的通道
                hw_wr_en      <= 1'b0;
            end

            else begin
                case (ac_diag_state)

                    // ====================================================
                    // IDLE: 等待any_ch_ac触发 (修复#7: 互斥检查)
                    // ====================================================
                    AC_DIAG_IDLE: begin
                        ch_ac_done  <= 4'b0000;
                        stage_timer <= 24'd0;
                        hw_wr_en    <= 1'b0;
                        // DC FSM运行时, AC不启动
                        if (any_ch_ac && !dc_fsm_busy) begin
                            ac_diag_state <= CH1_AC;
                        end
                    end

                    // ====================================================
                    // CH1_AC: 通道1 AC诊断 (修复#1: 跳过非诊断)
                    // ====================================================
                    CH1_AC: begin
                        if (!ch_ac_active[0]) begin
                            // CH1不在AC诊断 → 跳过
                            ac_diag_state <= CH2_AC;
                            stage_timer   <= 24'd0;
                        end else if (stage_timer < ac_timeout_val) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            rpt1_shadow <= ac_imp_ch0;
                            ac_diag_state <= CH2_AC;
                        end
                    end

                    // ====================================================
                    // CH2_AC (修复#1含跳过)
                    // ====================================================
                    CH2_AC: begin
                        if (!ch_ac_active[1]) begin
                            ac_diag_state <= CH3_AC;
                            stage_timer   <= 24'd0;
                        end else if (stage_timer < ac_timeout_val) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            rpt2_shadow <= ac_imp_ch1;
                            ac_diag_state <= CH3_AC;
                        end
                    end

                    // ====================================================
                    // CH3_AC (修复#1含跳过)
                    // ====================================================
                    CH3_AC: begin
                        if (!ch_ac_active[2]) begin
                            ac_diag_state <= CH4_AC;
                            stage_timer   <= 24'd0;
                        end else if (stage_timer < ac_timeout_val) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            rpt3_shadow <= ac_imp_ch2;
                            ac_diag_state <= CH4_AC;
                        end
                    end

                    // ====================================================
                    // CH4_AC (修复#1含跳过)
                    // ====================================================
                    CH4_AC: begin
                        if (!ch_ac_active[3]) begin
                            ac_diag_state <= AC_DONE;
                            stage_timer   <= 24'd0;
                        end else if (stage_timer < ac_timeout_val) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            rpt4_shadow <= ac_imp_ch3;
                            ac_diag_state <= AC_DONE;
                        end
                    end

                    // ====================================================
                    // AC_DONE: 全部完成, 写寄存器 + 通知通道
                    // ====================================================
                    AC_DONE: begin
                        // 写寄存器文件
                        ac_diag_rpt_ch1 <= rpt1_shadow;
                        ac_diag_rpt_ch2 <= rpt2_shadow;
                        ac_diag_rpt_ch3 <= rpt3_shadow;
                        ac_diag_rpt_ch4 <= rpt4_shadow;
                        {ac_phase_high, ac_phase_low} <= ac_phase_val;
                        {ac_sti_high, ac_sti_low}     <= ac_sti_val;
                        hw_wr_en   <= 1'b1;
                        hw_wr_addr <= 8'h17;  // 起始地址: 0x17
                        hw_wr_data <= rpt1_shadow;
                        // 通知所有参与AC诊断的通道
                        ch_ac_done <= ch_ac_active;
                        // 下一周期回IDLE
                        ac_diag_state <= AC_DIAG_IDLE;
                    end

                    default: ac_diag_state <= AC_DIAG_IDLE;
                endcase
            end
        end
    end

endmodule
