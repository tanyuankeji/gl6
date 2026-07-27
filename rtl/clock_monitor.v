// ============================================================================
// TAS6424E-Q1 时钟监控器
// 功能: 检测MCLK/SCLK/FSYNC活动, 超时报告clock_lost
// 设计: 内部含2级DFF CDC同步 (异步时钟输入 → clk域)
// ============================================================================

module clock_monitor #(
    parameter CLK_TIMEOUT_CYCLES = 24'hFFFFF
) (
    input  wire         clk,
    input  wire         rst_n,
    // 音频时钟输入 (异步, 内部含CDC同步)
    input  wire         mclk_i,
    input  wire         sclk_i,
    input  wire         fsync_i,
    // 使能 (chip_active=1时监控)
    input  wire         monitor_en,
    // 时钟丢失输出
    output wire         clock_lost,
    output wire         mclk_lost,
    output wire         sclk_lost,
    output wire         fsync_lost
);

    // ========================================================================
    // 2级DFF CDC同步: 异步时钟 → clk域
    // ========================================================================
    reg [1:0] mclk_sync, sclk_sync, fsync_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mclk_sync  <= 2'b00; sclk_sync <= 2'b00; fsync_sync <= 2'b00;
        end else begin
            mclk_sync  <= {mclk_sync[0],  mclk_i};
            sclk_sync  <= {sclk_sync[0],  sclk_i};
            fsync_sync <= {fsync_sync[0], fsync_i};
        end
    end

    // ========================================================================
    // 边沿检测
    // ========================================================================
    reg mclk_d, sclk_d, fsync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {mclk_d,sclk_d,fsync_d} <= 3'b000;
        else        {mclk_d,sclk_d,fsync_d} <= {mclk_sync[1],sclk_sync[1],fsync_sync[1]};
    end
    wire mclk_edge  = mclk_sync[1]  ^ mclk_d;
    wire sclk_edge  = sclk_sync[1]  ^ sclk_d;
    wire fsync_edge = fsync_sync[1] ^ fsync_d;

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
            mclk_cnt  <= mclk_edge  ? 24'd0
                       : (mclk_cnt < CLK_TIMEOUT_CYCLES)  ? mclk_cnt + 1'b1 : mclk_cnt;
            sclk_cnt  <= sclk_edge  ? 24'd0
                       : (sclk_cnt < CLK_TIMEOUT_CYCLES)  ? sclk_cnt + 1'b1 : sclk_cnt;
            fsync_cnt <= fsync_edge ? 24'd0
                       : (fsync_cnt < CLK_TIMEOUT_CYCLES) ? fsync_cnt + 1'b1 : fsync_cnt;
        end
    end

    assign mclk_lost  = monitor_en && (mclk_cnt >= CLK_TIMEOUT_CYCLES);
    assign sclk_lost  = monitor_en && (sclk_cnt >= CLK_TIMEOUT_CYCLES);
    assign fsync_lost = monitor_en && (fsync_cnt >= CLK_TIMEOUT_CYCLES);
    assign clock_lost = mclk_lost || sclk_lost || fsync_lost;

endmodule
