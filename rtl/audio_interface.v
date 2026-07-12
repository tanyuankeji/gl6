/**
 * Module: audio_interface
 * Description: 音频接口模块
 *              支持I2S/LJ/DSP/TDM等多种音频接口模式
 *              接收MCLK/SCLK/FSYNC/SDIN1/SDIN2输入
 *              输出4通道24位音频数据
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * SAP模式（0x03寄存器[2:0]）:
 *   000: I2S
 *   001: Left Justified
 *   010: DSP/PCM mode A
 *   011: DSP/PCM mode B
 *   100: TDM with 4 channels per SDIN1
 *   101: TDM with 4 channels per SDIN2
 *   110: Reserved
 *   111: Reserved
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - mclk: 音频主时钟
 *   - sclk: 音频位时钟（BCLK）
 *   - fsync: 帧同步信号（LRCLK）
 *   - sdin1: 音频数据输入1
 *   - sdin2: 音频数据输入2
 *   - sap_mode[2:0]: 音频接口模式选择
 *   - audio_data_ch1~4[23:0]: 4通道24位音频数据输出
 *   - audio_valid: 音频数据有效脉冲
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module audio_interface (
    input  wire        clk,
    input  wire        rst_n,

    // 音频总线输入
    input  wire        mclk,               // 音频主时钟
    input  wire        sclk,               // 位时钟（BCLK）
    input  wire        fsync,              // 帧同步（LRCLK）
    input  wire        sdin1,              // 数据输入1
    input  wire        sdin2,              // 数据输入2

    // 配置
    input  wire [2:0]  sap_mode,           // 音频接口模式

    // 音频数据输出
    output reg  [23:0] audio_data_ch1,     // 通道1音频数据
    output reg  [23:0] audio_data_ch2,     // 通道2音频数据
    output reg  [23:0] audio_data_ch3,     // 通道3音频数据
    output reg  [23:0] audio_data_ch4,     // 通道4音频数据
    output reg         audio_valid         // 数据有效脉冲（每帧一次）
);

    //----------------------------------------------------------
    // SCLK和FSYNC同步与边沿检测
    // 音频时钟域与系统时钟域之间需要同步
    //----------------------------------------------------------
    reg sclk_reg;
    reg sclk_prev;
    reg fsync_reg;
    reg fsync_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_reg  <= 1'b0;
            sclk_prev <= 1'b0;
            fsync_reg <= 1'b0;
            fsync_prev<= 1'b0;
        end else begin
            sclk_reg  <= sclk;
            sclk_prev <= sclk_reg;
            fsync_reg <= fsync;
            fsync_prev<= fsync_reg;
        end
    end

    // SCLK上升沿和下降沿脉冲
    wire sclk_rising  = sclk_reg & ~sclk_prev;
    wire sclk_falling = ~sclk_reg & sclk_prev;

    // FSYNC上升沿和下降沿脉冲
    wire fsync_rising  = fsync_reg & ~fsync_prev;
    wire fsync_falling = ~fsync_reg & fsync_prev;

    //----------------------------------------------------------
    // 位移寄存器和计数器
    //----------------------------------------------------------
    reg [23:0] shift_reg1;              // SDIN1位移寄存器
    reg [23:0] shift_reg2;              // SDIN2位移寄存器
    reg [4:0]  bit_cnt_reg;             // 位计数器（0-31 for TDM）
    reg        is_left_reg;             // 左右声道标志（I2S/LJ模式）

    // 临时数据缓存
    reg [23:0] data1_left_reg;          // SDIN1左声道数据
    reg [23:0] data1_right_reg;         // SDIN1右声道数据
    reg [23:0] data2_left_reg;          // SDIN2左声道数据
    reg [23:0] data2_right_reg;         // SDIN2右声道数据

    // TDM模式下4通道缓存
    reg [23:0] tdm_slot0_reg;           // TDM slot0
    reg [23:0] tdm_slot1_reg;           // TDM slot1
    reg [23:0] tdm_slot2_reg;           // TDM slot2
    reg [23:0] tdm_slot3_reg;           // TDM slot3

    //----------------------------------------------------------
    // FSYNC边沿处理：帧开始检测，复位位计数器
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt_reg <= 5'd0;
            is_left_reg <= 1'b0;
            audio_valid <= 1'b0;
        end else begin
            audio_valid <= 1'b0;        // 默认拉低

            if (fsync_rising) begin
                bit_cnt_reg <= 5'd0;
                is_left_reg <= 1'b1;    // FSYNC高=左声道（I2S）
            end else if (fsync_falling) begin
                is_left_reg <= 1'b0;    // FSYNC低=右声道（I2S）
                // 在I2S/LJ模式下，右声道结束表示一帧完成
                if (sap_mode <= 3'd1) begin
                    audio_valid <= 1'b1;
                end
            end else if (sclk_rising) begin
                bit_cnt_reg <= bit_cnt_reg + 5'd1;
                // TDM模式：32个SCLK周期后帧完成
                if (sap_mode >= 3'd4 && bit_cnt_reg == 5'd31) begin
                    audio_valid <= 1'b1;
                end
                // DSP模式：16个SCLK周期后帧完成（半帧）
                if (sap_mode >= 3'd2 && sap_mode <= 3'd3 && bit_cnt_reg == 5'd31) begin
                    audio_valid <= 1'b1;
                end
            end
        end
    end

    //----------------------------------------------------------
    // 音频数据位移接收
    // 在SCLK上升沿采样SDIN，MSB先入
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg1 <= 24'd0;
            shift_reg2 <= 24'd0;
        end else begin
            if (sclk_rising) begin
                shift_reg1 <= {shift_reg1[22:0], sdin1};
                shift_reg2 <= {shift_reg2[22:0], sdin2};
            end
        end
    end

    //----------------------------------------------------------
    // I2S/LJ模式数据处理
    // I2S: FSYNC下降沿后第一个SCLK开始左声道数据（延迟1 BCLK）
    // LJ:  FSYNC边沿同时开始数据（无延迟）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data1_left_reg  <= 24'd0;
            data1_right_reg <= 24'd0;
            data2_left_reg  <= 24'd0;
            data2_right_reg <= 24'd0;
        end else begin
            // I2S模式：第24个SCLK后锁存左声道
            if (sap_mode == 3'd0) begin
                if (is_left_reg && bit_cnt_reg == 5'd24) begin
                    data1_left_reg  <= shift_reg1;
                    data2_left_reg  <= shift_reg2;
                end else if (!is_left_reg && bit_cnt_reg == 5'd24) begin
                    data1_right_reg <= shift_reg1;
                    data2_right_reg <= shift_reg2;
                end
            // LJ模式：FSYNC边沿后立即开始，23个SCLK后锁存
            end else if (sap_mode == 3'd1) begin
                if (is_left_reg && bit_cnt_reg == 5'd23) begin
                    data1_left_reg  <= shift_reg1;
                    data2_left_reg  <= shift_reg2;
                end else if (!is_left_reg && bit_cnt_reg == 5'd23) begin
                    data1_right_reg <= shift_reg1;
                    data2_right_reg <= shift_reg2;
                end
            end
        end
    end

    //----------------------------------------------------------
    // TDM模式数据处理
    // 4个slot，每slot 8位，共32个SCLK周期
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tdm_slot0_reg <= 24'd0;
            tdm_slot1_reg <= 24'd0;
            tdm_slot2_reg <= 24'd0;
            tdm_slot3_reg <= 24'd0;
        end else begin
            // TDM模式：在每8个SCLK边界锁存数据
            if (sap_mode >= 3'd4) begin
                if (sclk_rising) begin
                    case (bit_cnt_reg[4:3])
                        2'd0: tdm_slot0_reg <= shift_reg1;
                        2'd1: tdm_slot1_reg <= shift_reg1;
                        2'd2: tdm_slot2_reg <= shift_reg1;
                        2'd3: tdm_slot3_reg <= shift_reg1;
                    endcase
                end
            end
        end
    end

    //----------------------------------------------------------
    // 音频数据输出到4通道
    // I2S/LJ模式: SDIN1→CH1(左)/CH2(右), SDIN2→CH3(左)/CH4(右)
    // TDM模式: SDIN1→CH1~4 (slot0~3)
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_data_ch1 <= 24'd0;
            audio_data_ch2 <= 24'd0;
            audio_data_ch3 <= 24'd0;
            audio_data_ch4 <= 24'd0;
        end else begin
            if (audio_valid) begin
                if (sap_mode <= 3'd1) begin
                    // I2S/LJ模式
                    audio_data_ch1 <= data1_left_reg;
                    audio_data_ch2 <= data1_right_reg;
                    audio_data_ch3 <= data2_left_reg;
                    audio_data_ch4 <= data2_right_reg;
                end else if (sap_mode >= 3'd4) begin
                    // TDM模式
                    audio_data_ch1 <= tdm_slot0_reg;
                    audio_data_ch2 <= tdm_slot1_reg;
                    audio_data_ch3 <= tdm_slot2_reg;
                    audio_data_ch4 <= tdm_slot3_reg;
                end
            end
        end
    end

endmodule
