// ============================================================================
// TAS6424E-Q1 保护电路 (v6.0)
// 功能: 故障信号去毛刺 + OTSD自动恢复冷却
// 设计原则:
//   - 去毛刺: 信号需连续稳定FAULT_DEGLITCH_CYCLES周期才确认
//   - OTSD自动恢复: 冷却后自动清除 (需0x21 bit3=1)
// ============================================================================

module protection #(
    parameter FAULT_DEGLITCH_CYCLES = 100,    // 10us @10MHz
    parameter OTSD_RECOVERY_CYCLES  = 16777215 // ~1.68s @10MHz (可配置)
) (
    input  wire         clk,
    input  wire         rst_n,
    // 控制
    input  wire         clear_fault,
    input  wire         otsd_auto_recovery, // 0x21 bit3
    // 原始故障输入
    input  wire         otw_raw,
    input  wire         otsd_raw,
    input  wire [3:0]   otw_ch_raw,
    input  wire [3:0]   otsd_ch_raw,
    input  wire         vbat_uv_raw,
    input  wire         vbat_ov_raw,
    input  wire         pvdd_uv_raw,
    input  wire         pvdd_ov_raw,
    // 去毛刺后输出
    output wire         otw_int,
    output wire         otsd_int,
    output wire [3:0]   otw_ch_int,
    output wire [3:0]   otsd_ch_int,
    output wire         vbat_uv_int,
    output wire         vbat_ov_int,
    output wire         pvdd_uv_int,
    output wire         pvdd_ov_int,
    // OTSD恢复指示
    output wire         otsd_recovered
);

    // ========================================================================
    // 去毛刺滤波器实例 (生成块)
    // ========================================================================
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_deglitch_otw_ch
            deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_otw_ch (.clk(clk),.rst_n(rst_n),.sig_raw(otw_ch_raw[i]),.sig_filtered(otw_ch_int[i]));
            deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_otsd_ch(.clk(clk),.rst_n(rst_n),.sig_raw(otsd_ch_raw[i]),.sig_filtered(otsd_ch_int[i]));
        end
    endgenerate

    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_otw    (.clk(clk),.rst_n(rst_n),.sig_raw(otw_raw),.sig_filtered(otw_int));
    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_otsd   (.clk(clk),.rst_n(rst_n),.sig_raw(otsd_raw),.sig_filtered(otsd_int));
    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_vbat_uv(.clk(clk),.rst_n(rst_n),.sig_raw(vbat_uv_raw),.sig_filtered(vbat_uv_int));
    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_vbat_ov(.clk(clk),.rst_n(rst_n),.sig_raw(vbat_ov_raw),.sig_filtered(vbat_ov_int));
    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_pvdd_uv(.clk(clk),.rst_n(rst_n),.sig_raw(pvdd_uv_raw),.sig_filtered(pvdd_uv_int));
    deglitch_filter #(.CYCLES(FAULT_DEGLITCH_CYCLES)) u_pvdd_ov(.clk(clk),.rst_n(rst_n),.sig_raw(pvdd_ov_raw),.sig_filtered(pvdd_ov_int));

    // ========================================================================
    // OTSD自动恢复: 冷却计时器
    // ========================================================================
    reg [31:0] otsd_recovery_timer;
    reg        otsd_auto_clear;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            otsd_recovery_timer <= 32'd0;
            otsd_auto_clear    <= 1'b0;
        end else begin
            otsd_auto_clear <= 1'b0;
            if (clear_fault) begin
                otsd_recovery_timer <= 32'd0;
            end else if (otsd_int && otsd_auto_recovery) begin
                if (otsd_recovery_timer < OTSD_RECOVERY_CYCLES)
                    otsd_recovery_timer <= otsd_recovery_timer + 1'b1;
                else
                    otsd_auto_clear <= 1'b1;
            end else if (!otsd_int) begin
                otsd_recovery_timer <= 32'd0;
            end
        end
    end
    assign otsd_recovered = otsd_auto_clear;

endmodule

// ============================================================================
// 通用去毛刺滤波器
// ============================================================================
module deglitch_filter #(
    parameter CYCLES = 100,
    parameter CNT_WIDTH = 10
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sig_raw,
    output wire       sig_filtered
);
    reg [CNT_WIDTH-1:0] cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 0;
        else if (!sig_raw)
            cnt <= 0;
        else if (cnt < CYCLES)
            cnt <= cnt + 1'b1;
    end

    assign sig_filtered = (cnt >= CYCLES);
endmodule
