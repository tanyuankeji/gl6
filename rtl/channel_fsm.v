// ============================================================================
// TAS6424E-Q1 通道状态机 (v6.0)
// 功能: 每通道独立6态FSM，管理Hi-Z/Play/Mute/DC诊断/AC诊断
// 设计原则:
//   - 4通道独立实例化, 各自状态完全独立
//   - 由0x04寄存器2bit直接驱动 (无需芯片主FSM中介)
//   - ENTRY子状态作为与全局DC/AC诊断FSM的桥接
//   - 故障发生时锁存并强制回CH_HIGH_Z
//   - 支持LDG_BYPASS禁止自动诊断
//   - 支持硬件MUTE引脚独立控制每通道
// ============================================================================

module channel_fsm #(
    parameter CHANNEL_ID = 0                 // 通道编号 0/1/2/3 (用于调试)
) (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 芯片全局控制
    input  wire         chip_active,         // chip_state == ACT
    input  wire         global_fault,        // 全局故障 (OV/UV/OTSD/clock_lost)
    input  wire         clear_fault,         // 0x21 bit7 清除故障锁存
    // 0x04 寄存器配置 (每通道2bit, 由顶层 allocate)
    // 编码: 00=PLAY, 01=HI_Z, 10=MUTE, 11=DC_DIAG
    input  wire [1:0]   ch_state_req,
    // 诊断控制
    input  wire         ldg_bypass,          // 0x09 bit0: 1=禁止自动诊断
    input  wire         ac_diag_en,          // 0x15/0x16: AC诊断使能
    // 硬件MUTE引脚 (低有效, 经去抖)
    input  wire         hw_mute_n,           // 0=静音, 1=正常
    // 故障输入
    input  wire         ch_fault,            // 通道故障 (OC/DC detect, 来自fault_monitor)
    // 诊断完成信号 (来自全局诊断FSM)
    input  wire         ch_diag_done,        // 全局DC FSM完成该通道
    input  wire         ch_ac_done,          // 全局AC FSM完成该通道
    input  wire         dc_ldg_abort,        // 0x09 bit7: 中止DC诊断
    // 通道状态输出
    output reg  [2:0]   ch_state,            // 6态时序寄存器
    output wire         ch_en,               // PWM使能
    output wire         ch_mute_mode,        // 静音模式 (50%占空比)
    output wire         ch_diag_active,      // DC诊断激活
    output wire         ch_ac_active,        // AC诊断激活
    output reg          ch_fault_latched     // 故障锁存 (用于0x0F上报)
);

    // ========================================================================
    // 参数定义
    // ========================================================================
    localparam CH_IDLE          = 3'd0;  // 上电初始
    localparam CH_HIGH_Z        = 3'd1;  // 高阻/默认 (0x04=01)
    localparam CH_PLAY          = 3'd2;  // 播放 (0x04=00)
    localparam CH_MUTE          = 3'd3;  // 静音 (0x04=10 or hw_mute_n=0)
    localparam CH_DC_DIAG_ENTRY = 3'd4;  // DC诊断桥接 (0x04=11)
    localparam CH_AC_DIAG_ENTRY = 3'd5;  // AC诊断桥接 (0x15/0x16)

    // ========================================================================
    // 故障锁存 (修复#5: 全局故障也锁存)
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_fault_latched <= 1'b0;
        end else if (clear_fault) begin
            ch_fault_latched <= 1'b0;
        end else if (ch_fault || global_fault) begin
            // 全局故障也锁存(用于0x0F上报, 即使通道不在故障态)
            ch_fault_latched <= 1'b1;
        end
    end

    // ========================================================================
    // 时序逻辑: 通道状态机 (6态)
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_state <= CH_IDLE;
        end else begin

            // ---- 优先级0: 芯片非ACT → 强制Hi-Z ----
            if (!chip_active) begin
                ch_state <= CH_HIGH_Z;
            end
            // ---- 优先级1: 全局故障 → 强制Hi-Z (修复#5) ----
            else if (global_fault) begin
                ch_state <= CH_HIGH_Z;
            end
            // ---- 优先级2: 通道故障 → 强制Hi-Z ----
            else if (ch_fault_latched) begin
                ch_state <= CH_HIGH_Z;
            end
            // ---- 优先级3: DC诊断中止 (修复#3) ----
            else if (dc_ldg_abort && (ch_state == CH_DC_DIAG_ENTRY)) begin
                ch_state <= CH_HIGH_Z;
            end
            else begin
                case (ch_state)

                    // -------------------------------------------------------
                    // IDLE: 复位后初始化
                    // -------------------------------------------------------
                    CH_IDLE: begin
                        ch_state <= CH_HIGH_Z;
                    end

                    // -------------------------------------------------------
                    // CH_HIGH_Z: 默认/复位状态
                    // -------------------------------------------------------
                    CH_HIGH_Z: begin
                        // 手动DC诊断 (0x04=11, 不受ldg_bypass影响)
                        if (ch_state_req == 2'b11) begin
                            ch_state <= CH_DC_DIAG_ENTRY;
                        end
                        // AC诊断 (0x15/0x16配置)
                        else if (ac_diag_en) begin
                            ch_state <= CH_AC_DIAG_ENTRY;
                        end
                        // 播放 (0x04=00)
                        else if (ch_state_req == 2'b00) begin
                            ch_state <= CH_PLAY;
                        end
                        // 静音 (0x04=10)
                        else if (ch_state_req == 2'b10) begin
                            ch_state <= CH_MUTE;
                        end
                        // 0x04=01 → 保持Hi-Z
                    end

                    // -------------------------------------------------------
                    // CH_PLAY: 播放
                    // -------------------------------------------------------
                    CH_PLAY: begin
                        // 手动DC诊断
                        if (ch_state_req == 2'b11) begin
                            ch_state <= CH_DC_DIAG_ENTRY;
                        end
                        // 静音 (0x04=10 或 硬件MUTE_N=0)
                        else if ((ch_state_req == 2'b10) || !hw_mute_n) begin
                            ch_state <= CH_MUTE;
                        end
                        // 回Hi-Z (0x04=01)
                        else if (ch_state_req == 2'b01) begin
                            ch_state <= CH_HIGH_Z;
                        end
                    end

                    // -------------------------------------------------------
                    // CH_MUTE: 静音
                    // -------------------------------------------------------
                    CH_MUTE: begin
                        // 手动DC诊断
                        if (ch_state_req == 2'b11) begin
                            ch_state <= CH_DC_DIAG_ENTRY;
                        end
                        // 回到播放 (0x04=00 且 硬件MUTE_N=1)
                        else if ((ch_state_req == 2'b00) && hw_mute_n) begin
                            ch_state <= CH_PLAY;
                        end
                        // 回Hi-Z (0x04=01)
                        else if (ch_state_req == 2'b01) begin
                            ch_state <= CH_HIGH_Z;
                        end
                    end

                    // -------------------------------------------------------
                    // CH_DC_DIAG_ENTRY: DC诊断桥接
                    // -------------------------------------------------------
                    CH_DC_DIAG_ENTRY: begin
                        // 全局DC FSM完成该通道 → 回Hi-Z
                        if (ch_diag_done) begin
                            ch_state <= CH_HIGH_Z;
                        end
                        // abort (由优先级3处理, 此处为fallback)
                        // 注意: abort也会设置ch_diag_done=1, 优先走上面分支
                    end

                    // -------------------------------------------------------
                    // CH_AC_DIAG_ENTRY: AC诊断桥接
                    // -------------------------------------------------------
                    CH_AC_DIAG_ENTRY: begin
                        if (ch_ac_done) begin
                            ch_state <= CH_HIGH_Z;
                        end
                    end

                    default: ch_state <= CH_HIGH_Z;
                endcase
            end
        end
    end

    // ========================================================================
    // 组合逻辑: 通道使能信号派生
    // ========================================================================
    assign ch_en          = (ch_state == CH_PLAY) || (ch_state == CH_MUTE);
    assign ch_mute_mode   = (ch_state == CH_MUTE);
    assign ch_diag_active = (ch_state == CH_DC_DIAG_ENTRY);
    assign ch_ac_active   = (ch_state == CH_AC_DIAG_ENTRY);

endmodule
