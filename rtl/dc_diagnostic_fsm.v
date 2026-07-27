// ============================================================================
// TAS6424E-Q1 DC诊断状态机 (v6.0, 15态)
// 功能: 全局DC负载诊断 —— 对GND短路/对电源短路/短路负载/开路/线路输出
// 设计: 无任务/函数调用, 直接状态转换 (综合友好)
// ============================================================================

`include "tas6424e_defines.vh"

module dc_diagnostic_fsm (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         any_ch_diag,
    input  wire         ac_fsm_busy,
    input  wire         dc_ldg_abort,
    input  wire [3:0]   ch_diag_active,
    input  wire [3:0]   ch_ac_active,
    input  wire [3:0]   s2g_ch, s2p_ch, sl_ch, ol_ch, lo_ch,
    input  wire         two_x_settle,
    input  wire [23:0]  diag_timeout_val,
    output reg  [3:0]   dc_diag_state,
    output wire         dc_fsm_busy,
    output reg  [3:0]   ch_diag_done,
    output reg  [7:0]   dc_diag_rpt1,
    output reg  [7:0]   dc_diag_rpt2,
    output reg  [7:0]   dc_diag_rpt3,
    output reg          hw_wr_en,
    output reg  [7:0]   hw_wr_addr,
    output reg  [7:0]   hw_wr_data
);

    // ========================================================================
    // 内部信号
    // ========================================================================
    reg [23:0] stage_timer;
    wire       stage_timer_done;
    reg  [7:0] rpt1_shadow, rpt2_shadow, rpt3_shadow;
    reg  [1:0] hw_write_seq;

    assign stage_timer_done = (stage_timer >= diag_timeout_val);
    assign dc_fsm_busy = (dc_diag_state != DC_DIAG_IDLE) && (dc_diag_state != DC_DONE);
    wire [23:0] settle_cycles = two_x_settle ? 24'd20000 : 24'd10000;

    // ========================================================================
    // 时序逻辑: 状态机 + 计时器
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dc_diag_state  <= DC_DIAG_IDLE;
            stage_timer    <= 24'd0;
            ch_diag_done   <= 4'b0000;
            rpt1_shadow    <= 8'd0;
            rpt2_shadow    <= 8'd0;
            rpt3_shadow    <= 8'd0;
            hw_wr_en       <= 1'b0;
            hw_write_seq   <= 2'd0;
        end else begin
            // 中止处理
            if (dc_ldg_abort && dc_fsm_busy) begin
                dc_diag_state <= DC_DIAG_IDLE;
                stage_timer   <= 24'd0;
                ch_diag_done  <= ch_diag_active;
                hw_wr_en      <= 1'b0;
            end else begin
                case (dc_diag_state)

                    // ====================================================
                    // IDLE: 等待触发 (AC FSM互斥)
                    // ====================================================
                    DC_DIAG_IDLE: begin
                        ch_diag_done  <= 4'b0000;
                        stage_timer   <= 24'd0;
                        hw_wr_en      <= 1'b0;
                        if (any_ch_diag && !ac_fsm_busy)
                            dc_diag_state <= DC_DIAG_OBSERVATION;
                    end

                    // ====================================================
                    // OBSERVATION: 等待模拟前端建立偏置
                    // ====================================================
                    DC_DIAG_OBSERVATION: begin
                        if (stage_timer < settle_cycles) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            dc_diag_state <= DC_DIAG_CH1_S2GP;
                        end
                    end

                    // ====================================================
                    // S2GP: CH1 对GND/电源短路测试
                    // ====================================================
                    DC_DIAG_CH1_S2GP: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[0]) rpt1_shadow[7:6] <= {s2g_ch[0], s2p_ch[0]};
                            dc_diag_state <= DC_DIAG_CH2_S2GP;
                        end
                    end
                    DC_DIAG_CH2_S2GP: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[1]) rpt1_shadow[3:2] <= {s2g_ch[1], s2p_ch[1]};
                            dc_diag_state <= DC_DIAG_CH3_S2GP;
                        end
                    end
                    DC_DIAG_CH3_S2GP: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[2]) rpt2_shadow[7:6] <= {s2g_ch[2], s2p_ch[2]};
                            dc_diag_state <= DC_DIAG_CH4_S2GP;
                        end
                    end
                    DC_DIAG_CH4_S2GP: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[3]) rpt2_shadow[3:2] <= {s2g_ch[3], s2p_ch[3]};
                            dc_diag_state <= DC_DIAG_CH1_SLICK;
                        end
                    end

                    // ====================================================
                    // SLICK: CH1 短路负载+开路测试
                    // ====================================================
                    DC_DIAG_CH1_SLICK: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[0]) rpt1_shadow[5:4] <= {ol_ch[0], sl_ch[0]};
                            dc_diag_state <= DC_DIAG_CH2_SLICK;
                        end
                    end
                    DC_DIAG_CH2_SLICK: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[1]) rpt1_shadow[1:0] <= {ol_ch[1], sl_ch[1]};
                            dc_diag_state <= DC_DIAG_CH3_SLICK;
                        end
                    end
                    DC_DIAG_CH3_SLICK: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[2]) rpt2_shadow[5:4] <= {ol_ch[2], sl_ch[2]};
                            dc_diag_state <= DC_DIAG_CH4_SLICK;
                        end
                    end
                    DC_DIAG_CH4_SLICK: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[3]) rpt2_shadow[1:0] <= {ol_ch[3], sl_ch[3]};
                            dc_diag_state <= DC_DIAG_CH1_LO;
                        end
                    end

                    // ====================================================
                    // LO: 线路输出测试
                    // ====================================================
                    DC_DIAG_CH1_LO: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[0]) rpt3_shadow[0] <= lo_ch[0];
                            dc_diag_state <= DC_DIAG_CH2_LO;
                        end
                    end
                    DC_DIAG_CH2_LO: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[1]) rpt3_shadow[1] <= lo_ch[1];
                            dc_diag_state <= DC_DIAG_CH3_LO;
                        end
                    end
                    DC_DIAG_CH3_LO: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[2]) rpt3_shadow[2] <= lo_ch[2];
                            dc_diag_state <= DC_DIAG_CH4_LO;
                        end
                    end
                    DC_DIAG_CH4_LO: begin
                        if (!stage_timer_done) begin
                            stage_timer <= stage_timer + 1'b1;
                        end else begin
                            stage_timer <= 24'd0;
                            if (ch_diag_active[3]) rpt3_shadow[3] <= lo_ch[3];
                            dc_diag_state <= DC_DONE;
                            hw_write_seq  <= 2'd0;
                        end
                    end

                    // ====================================================
                    // DONE: 顺序写3个寄存器 + 通知通道
                    // ====================================================
                    DC_DONE: begin
                        case (hw_write_seq)
                            2'd0: begin hw_wr_en <= 1'b1; hw_wr_addr <= 8'h0C; hw_wr_data <= rpt1_shadow; hw_write_seq <= 2'd1; end
                            2'd1: begin hw_wr_en <= 1'b1; hw_wr_addr <= 8'h0D; hw_wr_data <= rpt2_shadow; hw_write_seq <= 2'd2; end
                            2'd2: begin
                                hw_wr_en <= 1'b1; hw_wr_addr <= 8'h0E; hw_wr_data <= rpt3_shadow;
                                ch_diag_done <= ch_diag_active;
                                hw_write_seq <= 2'd3;
                            end
                            default: begin hw_wr_en <= 1'b0; dc_diag_state <= DC_DIAG_IDLE; end
                        endcase
                    end

                    default: dc_diag_state <= DC_DIAG_IDLE;
                endcase
            end
        end
    end

    // 组合输出
    assign dc_diag_rpt1 = rpt1_shadow;
    assign dc_diag_rpt2 = rpt2_shadow;
    assign dc_diag_rpt3 = rpt3_shadow;

endmodule
