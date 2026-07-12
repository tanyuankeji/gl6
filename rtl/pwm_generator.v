/**
 * Module: pwm_generator
 * Description: PWM生成器模块（4通道BTL输出）
 *              PLAY态：根据音频数据进行PWM调制
 *              MUTE态：输出50%占空比方波
 *              Hi-Z态：输出高阻态（0）
 *              支持PWM频率配置（0x02寄存器bit[6:4]）
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * PWM频率配置:
 *   3'b000: 8×fs  (~384kHz @48kHz)
 *   3'b001: 16×fs (~768kHz)
 *   3'b010: 22×fs (~1.06MHz)
 *   3'b011: 32×fs (~1.54MHz)
 *   3'b100: 44×fs (~2.11MHz) ← 默认
 *   3'b101: 48×fs (~2.30MHz)
 *   3'b110: 64×fs (~3.07MHz)
 *   3'b111: Reserved
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - audio_data_ch1~4[23:0]: 4通道音频数据
 *   - ch1_en~ch4_en: 通道使能
 *   - ch1_mute~ch4_mute: 通道静音模式
 *   - pwm_freq[2:0]: PWM频率配置
 *   - out_1p/1m~4p/4m: 4通道BTL PWM输出
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module pwm_generator (
    input  wire        clk,
    input  wire        rst_n,

    // 音频数据输入
    input  wire [23:0] audio_data_ch1,
    input  wire [23:0] audio_data_ch2,
    input  wire [23:0] audio_data_ch3,
    input  wire [23:0] audio_data_ch4,

    // 通道控制
    input  wire        ch1_en,             // 通道1使能
    input  wire        ch2_en,             // 通道2使能
    input  wire        ch3_en,             // 通道3使能
    input  wire        ch4_en,             // 通道4使能
    input  wire        ch1_mute,           // 通道1静音模式
    input  wire        ch2_mute,           // 通道2静音模式
    input  wire        ch3_mute,           // 通道3静音模式
    input  wire        ch4_mute,           // 通道4静音模式

    // 配置
    input  wire [2:0]  pwm_freq,           // PWM频率配置

    // PWM输出（BTL：每通道正负输出）
    output reg         out_1p,             // 通道1正输出
    output reg         out_1m,             // 通道1负输出
    output reg         out_2p,             // 通道2正输出
    output reg         out_2m,             // 通道2负输出
    output reg         out_3p,             // 通道3正输出
    output reg         out_3m,             // 通道3负输出
    output reg         out_4p,             // 通道4正输出
    output reg         out_4m              // 通道4负输出
);

    //----------------------------------------------------------
    // PWM载波计数器
    // 根据pwm_freq配置决定计数器周期
    // 系统时钟10MHz，PWM频率2.1MHz → 计数器周期约5
    //----------------------------------------------------------
    // PWM计数器最大值（决定开关频率）
    // 简化设计：使用8位计数器，比较音频数据高8位
    reg [7:0] pwm_cnt_reg;                 // PWM载波计数器

    // 不同PWM频率对应的计数器最大值
    // 系统时钟10MHz: 2.1MHz→5, 1.54MHz→6, 1.06MHz→9, 768kHz→13
    reg [7:0] pwm_max_val;
    always @(*) begin
        case (pwm_freq)
            3'b000: pwm_max_val = 8'd39;   // 8×fs  → ~256kHz
            3'b001: pwm_max_val = 8'd19;   // 16×fs → ~512kHz
            3'b010: pwm_max_val = 8'd14;   // 22×fs → ~711kHz
            3'b011: pwm_max_val = 8'd9;    // 32×fs → ~1.0MHz
            3'b100: pwm_max_val = 8'd7;    // 44×fs → ~1.25MHz
            3'b101: pwm_max_val = 8'd6;    // 48×fs → ~1.43MHz
            3'b110: pwm_max_val = 8'd5;    // 64×fs → ~1.67MHz
            default: pwm_max_val = 8'd7;   // 默认44×fs
        endcase
    end

    //----------------------------------------------------------
    // PWM载波计数器（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_cnt_reg <= 8'd0;
        end else begin
            if (pwm_cnt_reg >= pwm_max_val) begin
                pwm_cnt_reg <= 8'd0;       // 归零
            end else begin
                pwm_cnt_reg <= pwm_cnt_reg + 8'd1;
            end
        end
    end

    //----------------------------------------------------------
    // 音频数据比较值（取高8位作为PWM占空比比较）
    // 24位音频数据取高8位，映射到PWM计数器范围
    //----------------------------------------------------------
    wire [7:0] cmp_ch1 = {~audio_data_ch1[23], audio_data_ch1[22:16]};  // 转换为无符号
    wire [7:0] cmp_ch2 = {~audio_data_ch2[23], audio_data_ch2[22:16]};
    wire [7:0] cmp_ch3 = {~audio_data_ch3[23], audio_data_ch3[22:16]};
    wire [7:0] cmp_ch4 = {~audio_data_ch4[23], audio_data_ch4[22:16]};

    // 缩放到PWM计数器范围
    wire [7:0] scaled_max = pwm_max_val;
    wire [7:0] cmp_ch1_scaled = (cmp_ch1 * scaled_max) >> 8;
    wire [7:0] cmp_ch2_scaled = (cmp_ch2 * scaled_max) >> 8;
    wire [7:0] cmp_ch3_scaled = (cmp_ch3 * scaled_max) >> 8;
    wire [7:0] cmp_ch4_scaled = (cmp_ch4 * scaled_max) >> 8;

    //----------------------------------------------------------
    // PWM输出生成（时序逻辑）
    // PLAY态：计数器 < 比较值时正输出高，否则负输出高
    // MUTE态：50%占空比（计数器 < max/2时正输出高）
    // Hi-Z态：输出0
    //----------------------------------------------------------

    // 通道1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_1p <= 1'b0;
            out_1m <= 1'b0;
        end else begin
            if (!ch1_en) begin
                // Hi-Z：输出0
                out_1p <= 1'b0;
                out_1m <= 1'b0;
            end else if (ch1_mute) begin
                // MUTE：50%占空比
                out_1p <= (pwm_cnt_reg < (pwm_max_val >> 1));
                out_1m <= (pwm_cnt_reg >= (pwm_max_val >> 1));
            end else begin
                // PLAY：音频调制
                out_1p <= (pwm_cnt_reg < cmp_ch1_scaled);
                out_1m <= (pwm_cnt_reg >= cmp_ch1_scaled);
            end
        end
    end

    // 通道2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_2p <= 1'b0;
            out_2m <= 1'b0;
        end else begin
            if (!ch2_en) begin
                out_2p <= 1'b0;
                out_2m <= 1'b0;
            end else if (ch2_mute) begin
                out_2p <= (pwm_cnt_reg < (pwm_max_val >> 1));
                out_2m <= (pwm_cnt_reg >= (pwm_max_val >> 1));
            end else begin
                out_2p <= (pwm_cnt_reg < cmp_ch2_scaled);
                out_2m <= (pwm_cnt_reg >= cmp_ch2_scaled);
            end
        end
    end

    // 通道3
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_3p <= 1'b0;
            out_3m <= 1'b0;
        end else begin
            if (!ch3_en) begin
                out_3p <= 1'b0;
                out_3m <= 1'b0;
            end else if (ch3_mute) begin
                out_3p <= (pwm_cnt_reg < (pwm_max_val >> 1));
                out_3m <= (pwm_cnt_reg >= (pwm_max_val >> 1));
            end else begin
                out_3p <= (pwm_cnt_reg < cmp_ch3_scaled);
                out_3m <= (pwm_cnt_reg >= cmp_ch3_scaled);
            end
        end
    end

    // 通道4
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_4p <= 1'b0;
            out_4m <= 1'b0;
        end else begin
            if (!ch4_en) begin
                out_4p <= 1'b0;
                out_4m <= 1'b0;
            end else if (ch4_mute) begin
                out_4p <= (pwm_cnt_reg < (pwm_max_val >> 1));
                out_4m <= (pwm_cnt_reg >= (pwm_max_val >> 1));
            end else begin
                out_4p <= (pwm_cnt_reg < cmp_ch4_scaled);
                out_4m <= (pwm_cnt_reg >= cmp_ch4_scaled);
            end
        end
    end

endmodule
