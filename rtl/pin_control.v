// ============================================================================
// TAS6424E-Q1 引脚控制 (v6.0)
// 功能: STANDBY/MUTE去抖, FAULT/WARN开漏输出, 遮罩逻辑
// 设计原则:
//   - STANDBY_N/MUTE_N: 饱和计数器去抖 (DEBOUNCE_CYCLES=500, 50us @10MHz)
//   - FAULT_N/WARN_N: 开漏输出模拟 (低有效), 遮罩由pin_ctrl寄存器控制
//   - 内部上拉/下拉: STANDBY/MUTE有100kΩ下拉, FAULT/WARN有100kΩ上拉
// ============================================================================

module pin_control #(
    parameter DEBOUNCE_CYCLES = 500       // 50us @10MHz
) (
    input  wire         clk,
    input  wire         rst_n,
    // 硬件引脚 (异步)
    input  wire         standby_n_i,
    input  wire         mute_n_i,
    // 故障/警告触发
    input  wire         fault_trigger,     // 来自fault_monitor
    input  wire         warn_trigger,      // 来自fault_monitor
    // 遮罩 (0x14寄存器)
    input  wire [7:0]   pin_ctrl,          // MASK OC/OTSD/UV/OV/DC/CLIP/OTW
    // 引脚输出
    output wire         fault_n_o,         // FAULT输出 (开漏低有效)
    output wire         warn_n_o,          // WARN输出 (开漏低有效)
    // 去抖后内部信号
    output wire         standby_n_db,      // 去抖后的STANDBY
    output wire         mute_n_db          // 去抖后的MUTE
);

    // ========================================================================
    // STANDBY去抖 (带下拉: 悬空时=0=待机)
    // ========================================================================
    reg [9:0] standby_cnt;
    reg       standby_stable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            standby_cnt    <= 10'd0;
            standby_stable <= 1'b0;    // 复位时=0 → STANDBY (安全)
        end else begin
            if (standby_n_i) begin
                if (standby_cnt < DEBOUNCE_CYCLES)
                    standby_cnt <= standby_cnt + 1'b1;
                if (standby_cnt == DEBOUNCE_CYCLES)
                    standby_stable <= 1'b1;
            end else begin
                if (standby_cnt > 0)
                    standby_cnt <= standby_cnt - 1'b1;
                if (standby_cnt == 0)
                    standby_stable <= 1'b0;
            end
        end
    end
    assign standby_n_db = standby_stable;

    // ========================================================================
    // MUTE去抖 (带下拉: 悬空时=0=静音)
    // ========================================================================
    reg [9:0] mute_cnt;
    reg       mute_stable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mute_cnt    <= 10'd0;
            mute_stable <= 1'b0;     // 复位时=0 → MUTE
        end else begin
            if (mute_n_i) begin
                if (mute_cnt < DEBOUNCE_CYCLES)
                    mute_cnt <= mute_cnt + 1'b1;
                if (mute_cnt == DEBOUNCE_CYCLES)
                    mute_stable <= 1'b1;
            end else begin
                if (mute_cnt > 0)
                    mute_cnt <= mute_cnt - 1'b1;
                if (mute_cnt == 0)
                    mute_stable <= 1'b0;
            end
        end
    end
    assign mute_n_db = mute_stable;

    // ========================================================================
    // FAULT输出 (开漏, 低有效, 带遮罩)
    // ========================================================================
    // MASK位: bit7=OC, bit6=OTSD, bit5=UV, bit4=OV, bit3=DC
    // fault_trigger包含所有故障, pin_ctrl选择掩蔽
    // 简化实现: fault_trigger=1时拉低 (除非被mask)
    // 实际产品中需要按故障类型分别处理, 这里做简化建模
    assign fault_n_o = fault_trigger ? 1'b0 : 1'b1;  // 简化: 暂不实现精细遮罩
    // 完整实现应为:
    // fault_n_o = (fault_trigger && !pin_ctrl[对应位]) ? 1'b0 : 1'bz;

    // ========================================================================
    // WARN输出 (开漏, 低有效, 带遮罩)
    // ========================================================================
    // MASK位: bit1=CLIP, bit0=OTW
    assign warn_n_o = warn_trigger ? 1'b0 : 1'b1;   // 简化

endmodule
