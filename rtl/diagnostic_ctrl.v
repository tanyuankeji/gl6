/**
 * Module: diagnostic_ctrl
 * Description: 诊断控制器模块
 *              DC负载诊断：检测开路、短路到地、短路到电池、通道间短路
 *              AC负载诊断：阻抗和相位测量
 *              诊断由0x04寄存器配置CH_DC_DIAG触发，主状态机进入DIAG态
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * DC诊断结果编码（每通道2位）:
 *   00: 正常
 *   01: 开路
 *   10: 短路到地
 *   11: 短路到电池
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - diag_trigger: 诊断触发脉冲（来自主状态机）
 *   - ch_diag_active[3:0]: 各通道诊断进行中标志
 *   - dc_diag_ctrl1~3: DC诊断控制寄存器
 *   - ac_diag_ctrl1~2: AC诊断控制寄存器
 *   - dc_diag_rpt1~3: DC诊断报告输出（到寄存器文件）
 *   - ac_diag_rpt_ch1~4: AC诊断报告输出
 *   - diag_done: 诊断完成信号（到主状态机）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module diagnostic_ctrl (
    input  wire        clk,
    input  wire        rst_n,

    // 触发与控制
    input  wire        diag_trigger,           // 诊断触发脉冲
    input  wire [3:0]  ch_diag_active,         // 各通道诊断进行中
    input  wire [7:0]  dc_diag_ctrl1,          // 0x09
    input  wire [7:0]  dc_diag_ctrl2,          // 0x0A
    input  wire [7:0]  dc_diag_ctrl3,          // 0x0B
    input  wire [7:0]  ac_diag_ctrl1,          // 0x15
    input  wire [7:0]  ac_diag_ctrl2,          // 0x16

    // 诊断结果输出
    output reg  [7:0]  dc_diag_rpt1,           // 0x0C: CH1-4 DC诊断结果
    output reg  [7:0]  dc_diag_rpt2,           // 0x0D
    output reg  [7:0]  dc_diag_rpt3,           // 0x0E
    output reg  [7:0]  ac_diag_rpt_ch1,        // 0x17
    output reg  [7:0]  ac_diag_rpt_ch2,        // 0x18
    output reg  [7:0]  ac_diag_rpt_ch3,        // 0x19
    output reg  [7:0]  ac_diag_rpt_ch4,        // 0x1A
    output reg         diag_done               // 诊断完成信号
);

    //----------------------------------------------------------
    // 诊断状态机
    //----------------------------------------------------------
    localparam DIAG_IDLE     = 2'd0;   // 空闲
    localparam DIAG_DC_RUN   = 2'd1;   // DC诊断运行中
    localparam DIAG_AC_RUN   = 2'd2;   // AC诊断运行中
    localparam DIAG_DONE     = 2'd3;   // 诊断完成

    reg [1:0]  diag_state_reg;
    reg [1:0]  diag_state_next;
    reg [19:0] diag_timer_reg;             // 诊断计时器

    //----------------------------------------------------------
    // 诊断状态寄存器（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diag_state_reg <= DIAG_IDLE;
        end else begin
            diag_state_reg <= diag_state_next;
        end
    end

    //----------------------------------------------------------
    // 下一状态组合逻辑
    //----------------------------------------------------------
    always @(*) begin
        diag_state_next = diag_state_reg;
        case (diag_state_reg)
            DIAG_IDLE: begin
                if (diag_trigger) begin
                    diag_state_next = DIAG_DC_RUN;
                end
            end
            DIAG_DC_RUN: begin
                // DC诊断持续约1000个周期（仿真加速）
                if (diag_timer_reg >= 20'd1000) begin
                    diag_state_next = DIAG_AC_RUN;
                end
            end
            DIAG_AC_RUN: begin
                // AC诊断持续约1000个周期
                if (diag_timer_reg >= 20'd1000) begin
                    diag_state_next = DIAG_DONE;
                end
            end
            DIAG_DONE: begin
                // 完成后返回空闲
                diag_state_next = DIAG_IDLE;
            end
            default: diag_state_next = DIAG_IDLE;
        endcase
    end

    //----------------------------------------------------------
    // 诊断计时器（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diag_timer_reg <= 20'd0;
        end else begin
            case (diag_state_reg)
                DIAG_DC_RUN, DIAG_AC_RUN: begin
                    diag_timer_reg <= diag_timer_reg + 20'd1;
                end
                default: begin
                    diag_timer_reg <= 20'd0;
                end
            endcase
        end
    end

    //----------------------------------------------------------
    // 诊断完成信号生成
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            diag_done <= 1'b0;
        end else begin
            if (diag_state_reg == DIAG_DONE) begin
                diag_done <= 1'b1;
            end else begin
                diag_done <= 1'b0;
            end
        end
    end

    //----------------------------------------------------------
    // DC诊断报告生成
    // 简化模型：根据诊断控制寄存器生成模拟结果
    // 实际芯片通过模拟前端测量负载阻抗，此处用数字模型模拟
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dc_diag_rpt1 <= 8'h00;
            dc_diag_rpt2 <= 8'h00;
            dc_diag_rpt3 <= 8'h00;
        end else begin
            if (diag_state_reg == DIAG_DC_RUN && diag_timer_reg == 20'd999) begin
                // dc_diag_rpt1: CH1[3:2], CH2[1:0] + CH1[7:6], CH2[5:4]状态
                // 简化：正常负载=00，根据控制寄存器模拟
                // 如果控制寄存器使能了诊断，且通道处于诊断态，返回正常(00)
                dc_diag_rpt1 <= 8'h00;  // CH1, CH2正常
                dc_diag_rpt2 <= 8'h00;  // CH3, CH4正常
                dc_diag_rpt3 <= 8'h00;  // 附加信息
            end
        end
    end

    //----------------------------------------------------------
    // AC诊断报告生成
    // 简化模型：返回固定阻抗值
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ac_diag_rpt_ch1 <= 8'h00;
            ac_diag_rpt_ch2 <= 8'h00;
            ac_diag_rpt_ch3 <= 8'h00;
            ac_diag_rpt_ch4 <= 8'h00;
        end else begin
            if (diag_state_reg == DIAG_AC_RUN && diag_timer_reg == 20'd999) begin
                // 返回模拟阻抗值（4Ω负载→编码值）
                ac_diag_rpt_ch1 <= 8'h40;   // 模拟4Ω
                ac_diag_rpt_ch2 <= 8'h40;
                ac_diag_rpt_ch3 <= 8'h40;
                ac_diag_rpt_ch4 <= 8'h40;
            end
        end
    end

endmodule
