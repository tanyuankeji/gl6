// ============================================================================
// TAS6424E-Q1 时钟监控器 (v6.0)
// 功能: 检测MCLK/SCLK/FSYNC活动, 超时报告clock_lost
// 设计原则:
//   - 3个独立活动检测计数器 (翻转时清零, 无翻转时递增)
//   - 仅在非STANDBY时监控 (monitor_en由chip_active控制)
//   - 超时: CLK_TIMEOUT_CYCLES (~100ms @10MHz)
//   - 时钟恢复后自动清除clock_lost
// ============================================================================

module clock_monitor #(
    parameter CLK_TIMEOUT_CYCLES = 24'hFFFFF
) (
    input  wire         clk,
    input  wire         rst_n,
    // 音频时钟输入 (已同步到clk域)
    input  wire         mclk_sync,
    input  wire         sclk_sync,
    input  wire         fsync_sync,
    // 使能 (chip_active==1时监控)
    input  wire         monitor_en,
    // 时钟丢失输出
    output wire         clock_lost,
    output wire         mclk_lost,
    output wire         sclk_lost,
    output wire         fsync_lost
);

    // ========================================================================
    // MCLK边沿检测
    // ========================================================================
    reg mclk_d1, sclk_d1, fsync_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {mclk_d1,sclk_d1,fsync_d1} <= 3'b000;
        else        {mclk_d1,sclk_d1,fsync_d1} <= {mclk_sync,sclk_sync,fsync_sync};
    end
    wire mclk_edge  = mclk_sync  ^ mclk_d1;
    wire sclk_edge  = sclk_sync  ^ sclk_d1;
    wire fsync_edge = fsync_sync ^ fsync_d1;

    // ========================================================================
    // 超时计数器
    // ========================================================================
    reg [23:0] mclk_cnt, sclk_cnt, fsync_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {mclk_cnt, sclk_cnt, fsync_cnt} <= 72'd0;
        end else if (!monitor_en) begin
            {mclk_cnt, sclk_cnt, fsync_cnt} <= 72'd0;
        end else begin
            // MCLK
            mclk_cnt <= mclk_edge ? 24'd0
                      : (mclk_cnt < CLK_TIMEOUT_CYCLES) ? mclk_cnt + 1'b1 : mclk_cnt;
            // SCLK
            sclk_cnt <= sclk_edge ? 24'd0
                      : (sclk_cnt < CLK_TIMEOUT_CYCLES) ? sclk_cnt + 1'b1 : sclk_cnt;
            // FSYNC
            fsync_cnt <= fsync_edge ? 24'd0
                       : (fsync_cnt < CLK_TIMEOUT_CYCLES) ? fsync_cnt + 1'b1 : fsync_cnt;
        end
    end

    assign mclk_lost  = monitor_en && (mclk_cnt >= CLK_TIMEOUT_CYCLES);
    assign sclk_lost  = monitor_en && (sclk_cnt >= CLK_TIMEOUT_CYCLES);
    assign fsync_lost = monitor_en && (fsync_cnt >= CLK_TIMEOUT_CYCLES);
    assign clock_lost = mclk_lost || sclk_lost || fsync_lost;

endmodule
