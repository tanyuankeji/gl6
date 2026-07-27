// ============================================================================
// TAS6424E-Q1 寄存器文件
// 功能: 0x00-0x79地址空间, 40+寄存器, R/W仲裁
// 设计: R/W寄存器I2C读写, R寄存器硬件写/I2C只读, 特殊位自清除
// ============================================================================

`include "tas6424e_defines.vh"

module register_file (
    input  wire         clk,
    input  wire         rst_n,
    // I2C读写接口
    input  wire         reg_wr_en,
    input  wire [7:0]   reg_wr_addr,
    input  wire [7:0]   reg_wr_data,
    input  wire         reg_rd_en,
    input  wire [7:0]   reg_rd_addr,
    output reg  [7:0]   reg_rd_data,
    // 硬件写入
    input  wire         hw_wr_en,
    input  wire [7:0]   hw_wr_addr,
    input  wire [7:0]   hw_wr_data,
    // 配置输出 (按功能分类)
    // ---- 控制类 ----
    output wire         soft_reset,         // 0x00 bit7
    output wire         pbtl_ch12,          // 0x00 bit4
    output wire         pbtl_ch34,          // 0x00 bit5
    // ---- 杂项控制 ----
    output wire         hpf_bypass,         // 0x01 bit7
    output wire [1:0]   otw_threshold,      // 0x01 bit6:5
    output wire         oc_level,           // 0x01 bit4
    output wire [1:0]   volume_rate,        // 0x01 bit3:2
    output wire [1:0]   gain_level,         // 0x01 bit1:0
    output wire [2:0]   pwm_freq,           // 0x02 bit6:4
    output wire [1:0]   output_phase_lsb,   // 0x02 bit1:0
    // ---- 音频接口 ----
    output wire [1:0]   input_sr,           // 0x03 bit7:6
    output wire         tdm_slot_sel,       // 0x03 bit5
    output wire         tdm_slot_size,      // 0x03 bit4
    output wire [2:0]   sap_mode,           // 0x03 bit2:0
    // ---- 通道控制 ----
    output wire [7:0]   ch_state_ctrl,      // 0x04
    // ---- DC诊断 ----
    output wire         dc_ldg_abort,       // 0x09 bit7
    output wire         ldg_bypass,         // 0x09 bit0
    output wire         ldg_lo_enable,      // 0x09 bit1
    output wire [1:0]   dc_ramp_settle,     // 0x09 bit6:5
    // ---- 引脚控制 ----
    output wire [7:0]   pin_ctrl,           // 0x14
    // ---- AC诊断 ----
    output wire [3:0]   ac_diag_en,         // 0x15 bit3:0
    // ---- 杂项控制3 ----
    output wire         clear_fault_pulse,  // 0x21 bit7
    output wire         otsd_auto_recovery, // 0x21 bit3
    // ---- 杂项控制5 ----
    output wire         phase_sel_msb       // 0x28 bit5
);

    // ========================================================================
    // 寄存器阵列 (128字节, 0x00-0x7F)
    // ========================================================================
    reg [7:0] reg_array [0:127];

    // ========================================================================
    // I2C写逻辑 (仅R/W寄存器)
    // ========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 128; i = i + 1)
                reg_array[i] <= 8'd0;
            // 加载默认值
            reg_array[8'h01] <= 8'h32;    // 0x01
            reg_array[8'h02] <= 8'h62;    // 0x02
            reg_array[8'h03] <= 8'h04;    // 0x03
            reg_array[8'h04] <= 8'h55;    // 0x04: 所有通道Hi-Z
            reg_array[8'h05] <= 8'hCF;    // 0x05-08: 音量 0dB
            reg_array[8'h06] <= 8'hCF;
            reg_array[8'h07] <= 8'hCF;
            reg_array[8'h08] <= 8'hCF;
            reg_array[8'h0A] <= 8'h11;    // 0x0A
            reg_array[8'h0B] <= 8'h11;    // 0x0B
            reg_array[8'h0F] <= 8'h55;    // 0x0F: 通道状态报告
            reg_array[8'h28] <= 8'h0A;    // 0x28
        end else begin
            if (reg_wr_en && !is_ro_reg(reg_wr_addr))
                reg_array[reg_wr_addr] <= reg_wr_data;
        end
    end

    // ========================================================================
    // 硬件写逻辑 (仅R寄存器)
    // ========================================================================
    always @(posedge clk) begin
        if (hw_wr_en && is_ro_reg(hw_wr_addr))
            reg_array[hw_wr_addr] <= hw_wr_data;
    end

    // ========================================================================
    // I2C读逻辑 (组合)
    // ========================================================================
    always @(*) reg_rd_data = reg_array[reg_rd_addr];

    // ========================================================================
    // soft_reset (0x00 bit7) - 自清除脉冲
    // ========================================================================
    reg soft_reset_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_array[8'h00][7] <= 1'b0;
            soft_reset_d <= 1'b0;
        end else begin
            soft_reset_d <= 1'b0;
            if (reg_wr_en && (reg_wr_addr == 8'h00) && reg_wr_data[7]) begin
                reg_array[8'h00][7] <= 1'b0;
                soft_reset_d <= 1'b1;
            end
        end
    end
    assign soft_reset = soft_reset_d;

    // ========================================================================
    // clear_fault (0x21 bit7) - 自清除脉冲
    // ========================================================================
    reg clear_fault_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_array[8'h21][7] <= 1'b0;
            clear_fault_d <= 1'b0;
        end else begin
            clear_fault_d <= 1'b0;
            if (reg_wr_en && (reg_wr_addr == 8'h21) && reg_wr_data[7]) begin
                reg_array[8'h21][7] <= 1'b0;
                clear_fault_d <= 1'b1;
            end
        end
    end
    assign clear_fault_pulse = clear_fault_d;

    // ========================================================================
    // 寄存器位域提取
    // ========================================================================
    assign pbtl_ch12    = reg_array[8'h00][4];
    assign pbtl_ch34    = reg_array[8'h00][5];
    assign hpf_bypass   = reg_array[8'h01][7];
    assign otw_threshold = reg_array[8'h01][6:5];
    assign oc_level     = reg_array[8'h01][4];
    assign volume_rate  = reg_array[8'h01][3:2];
    assign gain_level   = reg_array[8'h01][1:0];
    assign pwm_freq     = reg_array[8'h02][6:4];
    assign output_phase_lsb = reg_array[8'h02][1:0];
    assign input_sr     = reg_array[8'h03][7:6];
    assign tdm_slot_sel = reg_array[8'h03][5];
    assign tdm_slot_size = reg_array[8'h03][4];
    assign sap_mode     = reg_array[8'h03][2:0];
    assign ch_state_ctrl = reg_array[8'h04][7:0];
    assign dc_ldg_abort = reg_array[8'h09][7];
    assign ldg_bypass   = reg_array[8'h09][0];
    assign ldg_lo_enable = reg_array[8'h09][1];
    assign dc_ramp_settle = {reg_array[8'h09][6], reg_array[8'h09][5]};
    assign pin_ctrl     = reg_array[8'h14];
    assign ac_diag_en   = reg_array[8'h15][3:0];
    assign otsd_auto_recovery = reg_array[8'h21][3];
    assign phase_sel_msb = reg_array[8'h28][5];

endmodule
