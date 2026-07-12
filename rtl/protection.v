/**
 * Module: protection
 * Description: 保护电路模块
 *              过温/过压/欠压阈值检测
 *              OTSD自动恢复控制
 *              输入来自模拟前端的原始信号，输出到故障监控器
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - otw_raw: 过温警告原始输入
 *   - otsd_raw: 过温关断原始输入
 *   - vbat_uv_raw: VBAT欠压原始输入
 *   - vbat_ov_raw: VBAT过压原始输入
 *   - pvdd_uv_raw: PVDD欠压原始输入
 *   - pvdd_ov_raw: PVDD过压原始输入
 *   - otsd_auto_recovery: 过温自动恢复使能（0x21 bit3）
 *   - clear_fault: 清除故障
 *   - chip_state[2:0]: 芯片状态
 *   - otw: 去毛刺后过温警告
 *   - otsd: 去毛刺后过温关断
 *   - vbat_uv/vbat_ov/pvdd_uv/pvdd_ov: 去毛刺后电压信号
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module protection (
    input  wire        clk,
    input  wire        rst_n,

    // 原始故障输入（来自模拟前端）
    input  wire        otw_raw,            // 过温警告原始
    input  wire        otsd_raw,           // 过温关断原始
    input  wire        vbat_uv_raw,        // VBAT欠压原始
    input  wire        vbat_ov_raw,        // VBAT过压原始
    input  wire        pvdd_uv_raw,        // PVDD欠压原始
    input  wire        pvdd_ov_raw,        // PVDD过压原始

    // 控制
    input  wire        otsd_auto_recovery, // 过温自动恢复使能
    input  wire        clear_fault,
    input  wire [2:0]  chip_state,

    // 去毛刺后输出
    output reg         otw,
    output reg         otsd,
    output reg         vbat_uv,
    output reg         vbat_ov,
    output reg         pvdd_uv,
    output reg         pvdd_ov
);

    //----------------------------------------------------------
    // 故障去毛刺计数器
    // 连续检测到故障信号FAULT_DEGLITCH_CYCLES个周期才确认
    //----------------------------------------------------------
    reg [15:0] otw_deg_cnt_reg;
    reg [15:0] otsd_deg_cnt_reg;
    reg [15:0] vbat_uv_deg_cnt_reg;
    reg [15:0] vbat_ov_deg_cnt_reg;
    reg [15:0] pvdd_uv_deg_cnt_reg;
    reg [15:0] pvdd_ov_deg_cnt_reg;

    //----------------------------------------------------------
    // OTSD自动恢复冷却计时器
    // OTSD发生后，冷却OTSD_RECOVERY_CYCLES后自动恢复
    //----------------------------------------------------------
    reg [23:0] otsd_recovery_cnt_reg;
    reg        otsd_latched_reg;           // OTSD锁存
    reg        otsd_cooling_reg;           // 冷却中标志

    //----------------------------------------------------------
    // 去毛刺逻辑（时序）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            otw_deg_cnt_reg    <= 16'd0;
            otsd_deg_cnt_reg   <= 16'd0;
            vbat_uv_deg_cnt_reg<= 16'd0;
            vbat_ov_deg_cnt_reg<= 16'd0;
            pvdd_uv_deg_cnt_reg<= 16'd0;
            pvdd_ov_deg_cnt_reg<= 16'd0;
            otw     <= 1'b0;
            otsd    <= 1'b0;
            vbat_uv <= 1'b0;
            vbat_ov <= 1'b0;
            pvdd_uv <= 1'b0;
            pvdd_ov <= 1'b0;
        end else begin
            // OTW去毛刺
            if (otw_raw) begin
                if (otw_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    otw_deg_cnt_reg <= otw_deg_cnt_reg + 16'd1;
                end else begin
                    otw <= 1'b1;
                end
            end else begin
                otw_deg_cnt_reg <= 16'd0;
                otw <= 1'b0;
            end

            // OTSD去毛刺
            if (otsd_raw) begin
                if (otsd_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    otsd_deg_cnt_reg <= otsd_deg_cnt_reg + 16'd1;
                end else begin
                    otsd <= 1'b1;
                end
            end else begin
                otsd_deg_cnt_reg <= 16'd0;
                // OTSD由自动恢复或clear_fault清除
                if (!otsd_latched_reg) begin
                    otsd <= 1'b0;
                end
            end

            // VBAT UV去毛刺
            if (vbat_uv_raw) begin
                if (vbat_uv_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    vbat_uv_deg_cnt_reg <= vbat_uv_deg_cnt_reg + 16'd1;
                end else begin
                    vbat_uv <= 1'b1;
                end
            end else begin
                vbat_uv_deg_cnt_reg <= 16'd0;
                vbat_uv <= 1'b0;
            end

            // VBAT OV去毛刺
            if (vbat_ov_raw) begin
                if (vbat_ov_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    vbat_ov_deg_cnt_reg <= vbat_ov_deg_cnt_reg + 16'd1;
                end else begin
                    vbat_ov <= 1'b1;
                end
            end else begin
                vbat_ov_deg_cnt_reg <= 16'd0;
                vbat_ov <= 1'b0;
            end

            // PVDD UV去毛刺
            if (pvdd_uv_raw) begin
                if (pvdd_uv_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    pvdd_uv_deg_cnt_reg <= pvdd_uv_deg_cnt_reg + 16'd1;
                end else begin
                    pvdd_uv <= 1'b1;
                end
            end else begin
                pvdd_uv_deg_cnt_reg <= 16'd0;
                pvdd_uv <= 1'b0;
            end

            // PVDD OV去毛刺
            if (pvdd_ov_raw) begin
                if (pvdd_ov_deg_cnt_reg < `FAULT_DEGLITCH_CYCLES) begin
                    pvdd_ov_deg_cnt_reg <= pvdd_ov_deg_cnt_reg + 16'd1;
                end else begin
                    pvdd_ov <= 1'b1;
                end
            end else begin
                pvdd_ov_deg_cnt_reg <= 16'd0;
                pvdd_ov <= 1'b0;
            end
        end
    end

    //----------------------------------------------------------
    // OTSD自动恢复逻辑
    // OTSD发生后锁存，冷却时间到后自动清除（如果使能了自动恢复）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            otsd_latched_reg    <= 1'b0;
            otsd_cooling_reg    <= 1'b0;
            otsd_recovery_cnt_reg<= 24'd0;
        end else begin
            if (clear_fault) begin
                otsd_latched_reg <= 1'b0;
                otsd_cooling_reg <= 1'b0;
                otsd_recovery_cnt_reg <= 24'd0;
            end else if (otsd) begin
                // OTSD触发：锁存并开始冷却
                otsd_latched_reg <= 1'b1;
                otsd_cooling_reg <= 1'b1;
                otsd_recovery_cnt_reg <= 24'd0;
            end else if (otsd_cooling_reg) begin
                // 冷却中：计数
                if (otsd_recovery_cnt_reg < `OTSD_RECOVERY_CYCLES) begin
                    otsd_recovery_cnt_reg <= otsd_recovery_cnt_reg + 24'd1;
                end else begin
                    // 冷却完成
                    otsd_cooling_reg <= 1'b0;
                    if (otsd_auto_recovery) begin
                        otsd_latched_reg <= 1'b0;  // 自动恢复
                    end
                end
            end
        end
    end

endmodule
