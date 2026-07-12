/**
 * Module: pin_control
 * Description: 引脚控制模块
 *              STANDBY/MUTE引脚去抖动处理
 *              FAULT/WARN开漏输出驱动
 *              根据故障状态和寄存器配置控制输出引脚
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - standby_n_pin: STANDBY引脚输入（低有效）
 *   - mute_n_pin: MUTE引脚输入（低有效）
 *   - global_fault_irq: 全局故障信号
 *   - any_ch_fault: 任意通道故障
 *   - otw_warning: 过温警告
 *   - por_flag: POR标志
 *   - pin_ctrl_reg[7:0]: 0x14引脚控制寄存器
 *   - standby_n: 去抖动后的standby信号（到主状态机）
 *   - mute_n: 去抖动后的mute信号（到主状态机/通道控制）
 *   - fault_n: 故障输出引脚（开漏低有效）
 *   - warn_n: 警告输出引脚（开漏低有效）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module pin_control (
    input  wire        clk,
    input  wire        rst_n,

    // 引脚输入
    input  wire        standby_n_pin,       // STANDBY引脚（低有效）
    input  wire        mute_n_pin,          // MUTE引脚（低有效）

    // 内部信号
    input  wire        global_fault_irq,    // 全局故障
    input  wire        any_ch_fault,        // 任意通道故障
    input  wire        otw_warning,         // 过温警告
    input  wire        por_flag,            // POR标志
    input  wire [7:0]  pin_ctrl_reg,        // 0x14寄存器

    // 输出
    output reg         standby_n,           // 去抖动后standby（到主状态机）
    output reg         mute_n,              // 去抖动后mute
    output reg         fault_n,             // FAULT引脚（开漏，低有效）
    output reg         warn_n               // WARN引脚（开漏，低有效）
);

    //----------------------------------------------------------
    // 引脚去抖动计数器
    // 连续采样DEBOUNCE_CYCLES次相同值才更新
    //----------------------------------------------------------
    reg [15:0] standby_db_cnt_reg;
    reg [15:0] mute_db_cnt_reg;
    reg        standby_prev_reg;
    reg        mute_prev_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            standby_db_cnt_reg <= 16'd0;
            mute_db_cnt_reg    <= 16'd0;
            standby_prev_reg   <= 1'b1;     // 默认高（standby无效）
            mute_prev_reg      <= 1'b1;     // 默认高（mute无效）
            standby_n          <= 1'b1;     // 默认standby无效
            mute_n             <= 1'b1;     // 默认mute无效
        end else begin
            // STANDBY去抖动
            if (standby_n_pin == standby_prev_reg) begin
                if (standby_db_cnt_reg < `DEBOUNCE_CYCLES) begin
                    standby_db_cnt_reg <= standby_db_cnt_reg + 16'd1;
                end else begin
                    standby_n <= standby_n_pin;    // 稳定后更新
                end
            end else begin
                standby_prev_reg   <= standby_n_pin;
                standby_db_cnt_reg <= 16'd0;
            end

            // MUTE去抖动
            if (mute_n_pin == mute_prev_reg) begin
                if (mute_db_cnt_reg < `DEBOUNCE_CYCLES) begin
                    mute_db_cnt_reg <= mute_db_cnt_reg + 16'd1;
                end else begin
                    mute_n <= mute_n_pin;
                end
            end else begin
                mute_prev_reg   <= mute_n_pin;
                mute_db_cnt_reg <= 16'd0;
            end
        end
    end

    //----------------------------------------------------------
    // FAULT/WARN开漏输出
    // FAULT: 全局故障或通道故障时拉低
    // WARN:  过温警告或POR时拉低
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fault_n <= 1'b1;     // 开漏释放（高阻，上拉为高）
            warn_n  <= 1'b1;
        end else begin
            // FAULT: 全局故障或通道故障时拉低
            fault_n <= ~(global_fault_irq | any_ch_fault);

            // WARN: 过温警告或POR时拉低
            warn_n <= ~(otw_warning | por_flag);
        end
    end

endmodule
