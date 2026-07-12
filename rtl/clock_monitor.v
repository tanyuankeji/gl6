/**
 * Module: clock_monitor
 * Description: 时钟监控器模块
 *              监控MCLK/SCLK/FSYNC的存在性
 *              检测时钟频率异常或丢失
 *              输出clock_lost信号到故障监控器
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - mclk: 音频主时钟
 *   - sclk: 音频位时钟
 *   - fsync: 帧同步信号
 *   - chip_state[2:0]: 芯片状态（仅在Hi-Z/MUTE/PLAY态监控）
 *   - clock_lost: 时钟丢失信号（到故障监控器）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module clock_monitor (
    input  wire        clk,
    input  wire        rst_n,

    // 音频时钟输入
    input  wire        mclk,
    input  wire        sclk,
    input  wire        fsync,

    // 控制
    input  wire [2:0]  chip_state,         // 芯片状态

    // 输出
    output reg         clock_lost           // 时钟丢失信号
);

    //----------------------------------------------------------
    // 时钟同步与边沿检测
    //----------------------------------------------------------
    reg mclk_reg, mclk_prev;
    reg sclk_reg, sclk_prev;
    reg fsync_reg, fsync_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mclk_reg  <= 1'b0; mclk_prev <= 1'b0;
            sclk_reg  <= 1'b0; sclk_prev <= 1'b0;
            fsync_reg <= 1'b0; fsync_prev<= 1'b0;
        end else begin
            mclk_reg  <= mclk;  mclk_prev <= mclk_reg;
            sclk_reg  <= sclk;  sclk_prev <= sclk_reg;
            fsync_reg <= fsync; fsync_prev<= fsync_reg;
        end
    end

    // 时钟边沿脉冲
    wire mclk_edge  = mclk_reg  ^ mclk_prev;
    wire sclk_edge  = sclk_reg  ^ sclk_prev;
    wire fsync_edge = fsync_reg ^ fsync_prev;

    //----------------------------------------------------------
    // 时钟活动计数器
    // 每检测到时钟边沿重置计数器
    // 计数器溢出表示时钟丢失
    //----------------------------------------------------------
    reg [19:0] mclk_timeout_cnt_reg;
    reg [19:0] sclk_timeout_cnt_reg;
    reg [19:0] fsync_timeout_cnt_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mclk_timeout_cnt_reg  <= 20'd0;
            sclk_timeout_cnt_reg  <= 20'd0;
            fsync_timeout_cnt_reg <= 20'd0;
        end else begin
            // MCLK计数器：检测到边沿重置，否则递增
            if (mclk_edge) begin
                mclk_timeout_cnt_reg <= 20'd0;
            end else begin
                mclk_timeout_cnt_reg <= mclk_timeout_cnt_reg + 20'd1;
            end

            // SCLK计数器
            if (sclk_edge) begin
                sclk_timeout_cnt_reg <= 20'd0;
            end else begin
                sclk_timeout_cnt_reg <= sclk_timeout_cnt_reg + 20'd1;
            end

            // FSYNC计数器
            if (fsync_edge) begin
                fsync_timeout_cnt_reg <= 20'd0;
            end else begin
                fsync_timeout_cnt_reg <= fsync_timeout_cnt_reg + 20'd1;
            end
        end
    end

    //----------------------------------------------------------
    // 时钟丢失检测
    // 仅在Hi-Z/MUTE/PLAY态检测
    // 任一时钟超时即报告丢失
    //----------------------------------------------------------
    wire mclk_lost  = (mclk_timeout_cnt_reg  >= `CLK_TIMEOUT_CYCLES);
    wire sclk_lost  = (sclk_timeout_cnt_reg  >= `CLK_TIMEOUT_CYCLES);
    wire fsync_lost = (fsync_timeout_cnt_reg >= `CLK_TIMEOUT_CYCLES);

    wire clock_mon_active = (chip_state == `CHIP_HI_Z) ||
                            (chip_state == `CHIP_MUTE) ||
                            (chip_state == `CHIP_PLAY);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clock_lost <= 1'b0;
        end else begin
            if (clock_mon_active) begin
                // 任一音频时钟丢失
                clock_lost <= mclk_lost | sclk_lost | fsync_lost;
            end else begin
                clock_lost <= 1'b0;     // 非监控态不报丢失
            end
        end
    end

endmodule
