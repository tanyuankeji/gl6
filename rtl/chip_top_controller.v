// ============================================================================
// TAS6424E-Q1 芯片顶层控制器 (v6.0)
// 功能: 管理芯片全局状态 —— PowerOn过渡 / STANDBY待机 / ACT激活
// 设计原则:
//   - 3态FSM, 无芯片主状态机层 (Hi-Z/Play/Mute是通道级状态)
//   - STANDBY_N=0 → ACT (振荡器工作, 通道自由运行)
//   - STANDBY_N=1 → STANDBY (振荡器停止, 通道强制Hi-Z)
//   - 输出聚合信号 (any_ch_play, all_ch_hiz等) 是纯组合逻辑
// ============================================================================

module chip_top_controller (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // 上电状态
    input  wire         por_done,           // VDD上电 + POR释放 + I2C就绪
    // STANDBY引脚 (经pin_control去抖后)
    input  wire         standby_n_db,       // 去抖后的STANDBY_N (0=待机,1=正常工作)
    // 芯片状态输出
    output reg  [1:0]   chip_state,         // 0=POWERON, 1=STANDBY, 2=ACT
    output wire         chip_active,        // chip_state == ACT (便捷信号)
    output wire         oscillator_en,      // 振荡器使能 (ACT时=1)
    // 通道状态输入 (来自4个channel_fsm, 用于聚合)
    input  wire [2:0]   ch0_state,          // CH1当前状态
    input  wire [2:0]   ch1_state,          // CH2当前状态
    input  wire [2:0]   ch2_state,          // CH3当前状态
    input  wire [2:0]   ch3_state,          // CH4当前状态
    // 聚合信号输出 (纯组合)
    output wire         any_ch_play,        // 任意通道在Play
    output wire         any_ch_mute,        // 任意通道在Mute
    output wire         all_ch_hiz,         // 所有通道在Hi-Z
    output wire         any_ch_diag,        // 任意通道在DC诊断
    output wire         any_ch_ac           // 任意通道在AC诊断
);

    // ========================================================================
    // 参数定义
    // ========================================================================
    localparam CHIP_POWERON = 2'd0;  // 上电过渡
    localparam CHIP_STANDBY = 2'd1;  // 待机 (振荡器停, 电流<6μA)
    localparam CHIP_ACT     = 2'd2;  // 激活 (振荡器工作, 通道自由运行)

    // 通道状态编码 (与channel_fsm.v一致)
    localparam CH_HIGH_Z        = 3'd1;
    localparam CH_PLAY          = 3'd2;
    localparam CH_MUTE          = 3'd3;
    localparam CH_DC_DIAG_ENTRY = 3'd4;
    localparam CH_AC_DIAG_ENTRY = 3'd5;

    // ========================================================================
    // 时序逻辑: 状态机
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chip_state <= CHIP_POWERON;
        end else begin
            case (chip_state)
                // ---- POWERON: 等待上电完成 ----
                CHIP_POWERON: begin
                    if (por_done) begin
                        // 上电完成后根据STANDBY_N决定初始状态
                        // STANDBY_N=1 (高电平) → ACT (正常启动)
                        // STANDBY_N=0 (低电平) → STANDBY (进入待机)
                        chip_state <= standby_n_db ? CHIP_ACT : CHIP_STANDBY;
                    end
                end

                // ---- STANDBY: 低功耗待机 ----
                CHIP_STANDBY: begin
                    // STANDBY_N=1 (高) → ACT
                    if (standby_n_db)
                        chip_state <= CHIP_ACT;
                end

                // ---- ACT: 正常工作 ----
                CHIP_ACT: begin
                    // STANDBY_N=0 (低) → STANDBY
                    if (!standby_n_db)
                        chip_state <= CHIP_STANDBY;
                end

                default: chip_state <= CHIP_POWERON;
            endcase
        end
    end

    // ========================================================================
    // 组合逻辑: 便捷信号
    // ========================================================================
    assign chip_active   = (chip_state == CHIP_ACT);
    assign oscillator_en = (chip_state == CHIP_ACT);

    // ========================================================================
    // 组合逻辑: 聚合信号 (纯组合, 无状态寄存器)
    // 每个信号反映4通道的实时状态
    // ========================================================================
    assign any_ch_play = (ch0_state == CH_PLAY) || (ch1_state == CH_PLAY)
                      || (ch2_state == CH_PLAY) || (ch3_state == CH_PLAY);

    assign any_ch_mute = (ch0_state == CH_MUTE) || (ch1_state == CH_MUTE)
                      || (ch2_state == CH_MUTE) || (ch3_state == CH_MUTE);

    assign all_ch_hiz  = (ch0_state == CH_HIGH_Z) && (ch1_state == CH_HIGH_Z)
                      && (ch2_state == CH_HIGH_Z) && (ch3_state == CH_HIGH_Z);

    assign any_ch_diag = (ch0_state == CH_DC_DIAG_ENTRY) || (ch1_state == CH_DC_DIAG_ENTRY)
                      || (ch2_state == CH_DC_DIAG_ENTRY) || (ch3_state == CH_DC_DIAG_ENTRY);

    assign any_ch_ac   = (ch0_state == CH_AC_DIAG_ENTRY) || (ch1_state == CH_AC_DIAG_ENTRY)
                      || (ch2_state == CH_AC_DIAG_ENTRY) || (ch3_state == CH_AC_DIAG_ENTRY);

endmodule
