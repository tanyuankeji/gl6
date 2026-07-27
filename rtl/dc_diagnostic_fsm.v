// ============================================================================
// TAS6424E-Q1 DC诊断状态机 (v6.0, 15态)
// 功能: 全局DC负载诊断 —— 对GND短路/对电源短路/短路负载/开路/线路输出
// 设计原则:
//   - 15态顺序FSM: IDLE→OBSERVATION→S2GP×4→SLICK×4→LO×4→DONE
//   - 修复#1: 每阶段跳过非诊断通道 (ch_diag_active[i]==0 → next)
//   - 修复#3: dc_ldg_abort立即中止, 所有ch_diag_done置1
//   - 修复#7: 与AC FSM互斥 (dc_busy时ac不能启动)
//   - 由any_ch_diag触发, 完成后ch_diag_done[i]通知通道FSM
// ============================================================================

module dc_diagnostic_fsm (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 触发/中止
    input  wire         any_ch_diag,        // 任意通道在CH_DC_DIAG_ENTRY → 触发
    input  wire         ac_fsm_busy,        // AC FSM正在运行 → 互斥等待 (修复#7)
    input  wire         dc_ldg_abort,       // 0x09 bit7: 中止DC诊断 (修复#3)
    // 通道诊断激活状态
    input  wire [3:0]   ch_diag_active,     // ch_diag_active[0:3] 来自channel_fsm
    input  wire [3:0]   ch_ac_active,       // 用于互斥检查
    // 模拟前端测量输入
    input  wire [3:0]   s2g_ch,             // 对GND短路检测
    input  wire [3:0]   s2p_ch,             // 对电源短路检测
    input  wire [3:0]   sl_ch,              // 短路负载检测
    input  wire [3:0]   ol_ch,              // 开路检测
    input  wire [3:0]   lo_ch,              // 线路输出检测
    // 诊断控制
    input  wire         two_x_settle,       // 0x09 bit5: 加倍稳定时间
    input  wire [23:0]  diag_timeout_val,   // 可配超时值
    // 诊断状态输出
    output reg  [3:0]   dc_diag_state,      // 当前FSM状态 (4bit)
    output wire         dc_fsm_busy,        // FSM正在运行 (=1时AC不能启动)
    // 完成信号 → 通道FSM (修复#1: 仅对参与的通道发送)
    output reg  [3:0]   ch_diag_done,       // ch_diag_done[i]=1 → 通道i诊断完成
    // 诊断报告 → register_file (硬件写)
    output reg  [7:0]   dc_diag_rpt1,       // 0x0C: CH1 S2G/S2P/OL/SL + CH2
    output reg  [7:0]   dc_diag_rpt2,       // 0x0D: CH3 + CH4
    output reg  [7:0]   dc_diag_rpt3,       // 0x0E: Line Output
    output reg          hw_wr_en,           // 硬件写使能
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);

    // ========================================================================
    // 状态编码 (15态)
    // ========================================================================
    localparam DC_DIAG_IDLE        = 4'd0;
    localparam DC_DIAG_OBSERVATION = 4'd1;   // 等待模拟前端建立偏置
    // 阶段1: S2G+S2P (对GND/电源短路)
    localparam DC_DIAG_CH1_S2GP    = 4'd2;
    localparam DC_DIAG_CH2_S2GP    = 4'd3;
    localparam DC_DIAG_CH3_S2GP    = 4'd4;
    localparam DC_DIAG_CH4_S2GP    = 4'd5;
    // 阶段2: SLICK (SL短路负载 + OL开路)
    localparam DC_DIAG_CH1_SLICK   = 4'd6;
    localparam DC_DIAG_CH2_SLICK   = 4'd7;
    localparam DC_DIAG_CH3_SLICK   = 4'd8;
    localparam DC_DIAG_CH4_SLICK   = 4'd9;
    // 阶段3: LO (线路输出)
    localparam DC_DIAG_CH1_LO      = 4'd10;
    localparam DC_DIAG_CH2_LO      = 4'd11;
    localparam DC_DIAG_CH3_LO      = 4'd12;
    localparam DC_DIAG_CH4_LO      = 4'd13;
    localparam DC_DONE             = 4'd14;

    // ========================================================================
    // 内部信号
    // ========================================================================
    reg [23:0] stage_timer;                 // 每阶段计时器
    wire       stage_timer_done;            // 阶段计时完成
    reg  [1:0] current_ch;                  // 当前通道索引 (0-3)
    reg  [7:0] rpt1_shadow, rpt2_shadow, rpt3_shadow;  // 报告影子寄存器
    reg  [1:0] hw_write_seq;               // 多寄存器写序列计数 (修复#4)
    wire       skip_ch0, skip_ch1, skip_ch2, skip_ch3;  // 跳过非诊断通道

    // 跳过非诊断通道 (修复#1: DC FSM仅处理ch_diag_active=1的通道)
    assign skip_ch0 = !ch_diag_active[0];
    assign skip_ch1 = !ch_diag_active[1];
    assign skip_ch2 = !ch_diag_active[2];
    assign skip_ch3 = !ch_diag_active[3];

    // OBSERVATION settle时间: 默认~1ms, 2x_SETTLE=1时加倍
    wire [23:0] settle_cycles = two_x_settle ? 24'd20000 : 24'd10000;  // 1ms/2ms @10MHz

    // 阶段计时完成检测
    assign stage_timer_done = (stage_timer >= diag_timeout_val);

    // FSM忙标志
    assign dc_fsm_busy = (dc_diag_state != DC_DIAG_IDLE) && (dc_diag_state != DC_DONE);

    // ========================================================================
    // 时序逻辑: 状态机 + 计时器
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dc_diag_state  <= DC_DIAG_IDLE;
            stage_timer    <= 24'd0;
            current_ch     <= 2'd0;
            ch_diag_done   <= 4'b0000;
            rpt1_shadow    <= 8'd0;
            rpt2_shadow    <= 8'd0;
            rpt3_shadow    <= 8'd0;
            hw_wr_en       <= 1'b0;
            hw_write_seq   <= 2'd0;
            // 硬件写延迟
            {dc_diag_rpt1, dc_diag_rpt2, dc_diag_rpt3} <= 24'd0;
            {hw_wr_addr, hw_wr_data} <= 16'd0;

        end else begin
            // ---- 中止处理 (修复#3: 全局优先级) ----
            if (dc_ldg_abort && dc_fsm_busy) begin
                dc_diag_state <= DC_DIAG_IDLE;
                stage_timer   <= 24'd0;
                // 所有等待诊断的通道收到done (包括被动等待的)
                ch_diag_done  <= ch_diag_active;
                hw_wr_en      <= 1'b0;
            end

            // ---- 正常状态机流程 ----
            else begin
                case (dc_diag_state)

                    // ====================================================
                    // IDLE: 等待any_ch_diag触发 (互斥检查)
                    // ====================================================
                    DC_DIAG_IDLE: begin
                        ch_diag_done  <= 4'b0000;
                        stage_timer   <= 24'd0;
                        hw_wr_en      <= 1'b0;
                        // 修复#7: AC FSM运行时, DC FSM不启动
                        if (any_ch_diag && !ac_fsm_busy) begin
                            dc_diag_state <= DC_DIAG_OBSERVATION;
                        end
                    end

                    // ====================================================
                    // OBSERVATION: 等待模拟前端建立偏置
                    // ====================================================
                    DC_DIAG_OBSERVATION: begin
                        if (stage_timer < settle_cycles) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            // 如果CH1在诊断 → 进入CH1_S2GP, 否则跳过
                            dc_diag_state <= skip_ch0 ? next_s2gp_state(2'd0) : DC_DIAG_CH1_S2GP;
                            current_ch    <= 2'd0;
                        end
                    end

                    // ====================================================
                    // 阶段1: CH1~CH4 S2GP (对GND/电源短路) — 修复#1含跳过
                    // ====================================================
                    DC_DIAG_CH1_S2GP: s2gp_test(0, DC_DIAG_CH2_S2GP);
                    DC_DIAG_CH2_S2GP: s2gp_test(1, DC_DIAG_CH3_S2GP);
                    DC_DIAG_CH3_S2GP: s2gp_test(2, DC_DIAG_CH4_S2GP);
                    DC_DIAG_CH4_S2GP: s2gp_test(3, DC_DIAG_CH1_SLICK);

                    // ====================================================
                    // 阶段2: CH1~CH4 SLICK (短路负载+开路) — 修复#1含跳过
                    // ====================================================
                    DC_DIAG_CH1_SLICK: slic_test(0, DC_DIAG_CH2_SLICK);
                    DC_DIAG_CH2_SLICK: slic_test(1, DC_DIAG_CH3_SLICK);
                    DC_DIAG_CH3_SLICK: slic_test(2, DC_DIAG_CH4_SLICK);
                    DC_DIAG_CH4_SLICK: slic_test(3, DC_DIAG_CH1_LO);

                    // ====================================================
                    // 阶段3: CH1~CH4 LO (线路输出) — 修复#1含跳过
                    // ====================================================
                    DC_DIAG_CH1_LO: lo_test(0, DC_DIAG_CH2_LO);
                    DC_DIAG_CH2_LO: lo_test(1, DC_DIAG_CH3_LO);
                    DC_DIAG_CH3_LO: lo_test(2, DC_DIAG_CH4_LO);
                    DC_DIAG_CH4_LO: lo_test(3, DC_DONE);

                    // ====================================================
                    // DONE: 全部完成, 顺序写3个寄存器 + 通知通道 (修复#4)
                    // ====================================================
                    DC_DONE: begin
                        case (hw_write_seq)
                            2'd0: begin
                                hw_wr_en   <= 1'b1;
                                hw_wr_addr <= 8'h0C;
                                hw_wr_data <= rpt1_shadow;
                                hw_write_seq <= 2'd1;
                            end
                            2'd1: begin
                                hw_wr_en   <= 1'b1;
                                hw_wr_addr <= 8'h0D;
                                hw_wr_data <= rpt2_shadow;
                                hw_write_seq <= 2'd2;
                            end
                            2'd2: begin
                                hw_wr_en   <= 1'b1;
                                hw_wr_addr <= 8'h0E;
                                hw_wr_data <= rpt3_shadow;
                                hw_write_seq <= 2'd3;
                                // 通知所有参与诊断的通道
                                ch_diag_done <= ch_diag_active;
                            end
                            default: begin
                                hw_wr_en     <= 1'b0;
                                hw_write_seq <= 2'd0;
                                dc_diag_state <= DC_DIAG_IDLE;
                            end
                        endcase
                    end

                    default: dc_diag_state <= DC_DIAG_IDLE;
                endcase
            end
        end
    end

    // ========================================================================
    // 任务: S2GP测试 (含报告锁存) — 修复#1
    // ========================================================================
    task s2gp_test(input integer ch, input [3:0] next_state);
        begin
            if (stage_timer < diag_timeout_val) begin
                stage_timer <= stage_timer + 1'b1;
            end else begin
                stage_timer <= 24'd0;
                // 锁存S2G/S2P结果
                if (ch_diag_active[ch]) begin
                    case (ch)
                        0: rpt1_shadow[7:6] <= {s2g_ch[0], s2p_ch[0]};
                        1: rpt1_shadow[3:2] <= {s2g_ch[1], s2p_ch[1]};
                        2: rpt2_shadow[7:6] <= {s2g_ch[2], s2p_ch[2]};
                        3: rpt2_shadow[3:2] <= {s2g_ch[3], s2p_ch[3]};
                    endcase
                end
                // 跳转到下一状态 (若下一通道非诊断则跳过)
                dc_diag_state <= skip_next_ch(ch, next_state);
                current_ch    <= ch + 1;
            end
        end
    endtask

    // ========================================================================
    // 任务: SLICK测试 (含报告锁存) — 修复#1
    // ========================================================================
    task slic_test(input integer ch, input [3:0] next_state);
        begin
            if (stage_timer < diag_timeout_val) begin
                stage_timer <= stage_timer + 1'b1;
            end else begin
                stage_timer <= 24'd0;
                // 锁存OL/SL结果
                if (ch_diag_active[ch]) begin
                    case (ch)
                        0: rpt1_shadow[5:4] <= {ol_ch[0], sl_ch[0]};
                        1: rpt1_shadow[1:0] <= {ol_ch[1], sl_ch[1]};
                        2: rpt2_shadow[5:4] <= {ol_ch[2], sl_ch[2]};
                        3: rpt2_shadow[1:0] <= {ol_ch[3], sl_ch[3]};
                    endcase
                end
                dc_diag_state <= skip_next_ch(ch, next_state);
                current_ch    <= ch + 1;
            end
        end
    endtask

    // ========================================================================
    // 任务: LO测试 (含报告锁存) — 修复#1
    // ========================================================================
    task lo_test(input integer ch, input [3:0] next_state);
        begin
            if (stage_timer < diag_timeout_val) begin
                stage_timer <= stage_timer + 1'b1;
            end else begin
                stage_timer <= 24'd0;
                // 锁存LO结果
                if (ch_diag_active[ch]) begin
                    rpt3_shadow[ch] <= lo_ch[ch];
                end
                // 最后一个通道(CH3=CH4)完成后直接到DONE
                if (ch == 3)
                    dc_diag_state <= DC_DONE;
                else
                    dc_diag_state <= skip_next_ch(ch, next_state);
                current_ch    <= ch + 1;
            end
        end
    endtask

    // ========================================================================
    // 辅助函数: 跳过非诊断通道 (修复#1)
    // ========================================================================
    function [3:0] skip_next_ch(input integer ch, input [3:0] next_state);
        begin
            // 检查下一个通道是否在诊断中
            case (ch)
                0: skip_next_ch = skip_ch1 ? next_s2gp_state(1) : next_state; // CH1→CH2
                1: skip_next_ch = skip_ch2 ? next_s2gp_state(2) : next_state;
                2: skip_next_ch = skip_ch3 ? next_s2gp_state(3) : next_state;
                3: skip_next_ch = next_state; // 最后一个通道, 不跳过
            endcase
        end
    endfunction

    // S2GP阶段的下一个状态映射
    function [3:0] next_s2gp_state(input [1:0] ch);
        case (ch)
            2'd0: next_s2gp_state = DC_DIAG_CH2_S2GP;
            2'd1: next_s2gp_state = DC_DIAG_CH3_S2GP;
            2'd2: next_s2gp_state = DC_DIAG_CH4_S2GP;
            2'd3: next_s2gp_state = DC_DIAG_CH1_SLICK;
        endcase
    endfunction

endmodule
