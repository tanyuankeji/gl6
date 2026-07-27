// ============================================================================
// TAS6424E-Q1 寄存器文件 (v6.0)
// 功能: 0x00-0x79地址空间, 40+寄存器, R/W仲裁, 自清除/脉冲型特殊处理
// 设计原则:
//   - R/W寄存器: I2C可读写, 硬件不可写
//   - R寄存器:   硬件可写, I2C只读
//   - soft_reset (0x00 b7) / clear_fault (0x21 b7): 自清除脉冲
//   - 子地址自增: 顺序读写时地址自动递增 (0x79→0x00回绕)
//   - 保留位/寄存器: 写忽略, 读返回0
// ============================================================================

module register_file (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C读写接口
    input  wire         reg_wr_en,          // I2C写使能脉冲 (1clk)
    input  wire [7:0]   reg_wr_addr,        // I2C写地址
    input  wire [7:0]   reg_wr_data,        // I2C写数据
    input  wire         reg_rd_en,          // I2C读使能脉冲 (1clk)
    input  wire [7:0]   reg_rd_addr,        // I2C读地址
    output reg  [7:0]   reg_rd_data,        // I2C读数据返回
    // 硬件写入接口 (来自内部模块)
    input  wire [7:0]   hw_wr_addr,         // 硬件写地址
    input  wire [7:0]   hw_wr_data,         // 硬件写数据
    input  wire         hw_wr_en,           // 硬件写使能脉冲 (1clk)
    // ==================== 模块配置输出 ====================
    // 0x00 模式控制
    output wire         soft_reset,         // bit7: 自清除脉冲
    output wire         pbtl_ch12,          // bit4: PBTL CH1/2
    output wire         pbtl_ch34,          // bit5: PBTL CH3/4
    // 0x01 杂项控制1
    output wire         hpf_bypass,         // bit7
    output wire [1:0]   otw_threshold,      // bit6:5
    output wire         oc_level,           // bit4
    output wire [1:0]   volume_rate,        // bit3:2
    output wire [1:0]   gain_level,         // bit1:0
    // 0x02 杂项控制2
    output wire [2:0]   pwm_freq,           // bit6:4
    output wire [1:0]   output_phase_lsb,   // bit1:0
    // 0x03 SAP控制
    output wire [1:0]   input_sr,           // bit7:6
    output wire         tdm_slot_sel,       // bit5
    output wire         tdm_slot_size,      // bit4
    output wire [2:0]   sap_mode,           // bit2:0
    // 0x04 通道状态控制 (核心!)
    output wire [7:0]   ch_state_ctrl,      // CH1~4 ×2bit: 00=PLAY,01=HI_Z,10=MUTE,11=DC
    // 0x09 DC诊断控制
    output wire         dc_ldg_abort,       // bit7: DC_LDG_ABORT (修复#1)
    output wire         ldg_bypass,         // bit0: LDG_BYPASS
    output wire         ldg_lo_enable,      // bit1
    output wire [1:0]   dc_ramp_settle,     // bit6:5
    // 0x14 引脚控制
    output wire [7:0]   pin_ctrl,
    // 0x15-0x16 AC诊断控制
    output wire [3:0]   ac_diag_en,         // 0x15 bit3:0
    // 0x21 杂项控制3
    output wire         clear_fault_pulse,  // bit7: 自清除脉冲
    output wire         otsd_auto_recovery, // bit3
    // 0x28 杂项控制5
    output wire         phase_sel_msb       // bit5
);

    // ========================================================================
    // 寄存器阵列 (128字节, 0x00-0x7F)
    // ========================================================================
    reg [7:0] reg_array [0:127];

    // ========================================================================
    // 只读寄存器判定 (R寄存器: 硬件可写, I2C只读)
    // ========================================================================
    function is_ro_reg(input [7:0] addr);
        case (addr)
            8'h0C, 8'h0D, 8'h0E,         // DC诊断报告
            8'h0F,                         // 通道状态报告
            8'h10, 8'h11, 8'h12, 8'h13,   // 故障/警告
            8'h17, 8'h18, 8'h19, 8'h1A,   // AC诊断报告CH1~4
            8'h1B, 8'h1C, 8'h1D, 8'h1E:   // AC相位/STI
                is_ro_reg = 1'b1;
            default:
                is_ro_reg = 1'b0;
        endcase
    endfunction

    // ========================================================================
    // I2C写逻辑 (仅R/W寄存器)
    // ========================================================================
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 128; i = i + 1)
                reg_array[i] <= 8'd0;
            // 加载默认值
            reg_array[8'h01] <= 8'h32;    // 0x01: Misc Control 1
            reg_array[8'h02] <= 8'h62;    // 0x02: Misc Control 2
            reg_array[8'h03] <= 8'h04;    // 0x03: SAP Control (I2S)
            reg_array[8'h04] <= 8'h55;    // 0x04: 所有通道Hi-Z
            reg_array[8'h05] <= 8'hCF;    // 0x05-08: 音量 - 0dB
            reg_array[8'h06] <= 8'hCF;
            reg_array[8'h07] <= 8'hCF;
            reg_array[8'h08] <= 8'hCF;
            reg_array[8'h0A] <= 8'h11;    // 0x0A: DC Diag Ctrl2
            reg_array[8'h0B] <= 8'h11;    // 0x0B: DC Diag Ctrl3
            reg_array[8'h0F] <= 8'h55;    // 0x0F: 通道状态报告 (全部Hi-Z) 修复#3
            reg_array[8'h28] <= 8'h0A;    // 0x28: Misc Control 5
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
    // I2C读逻辑 (组合, 保留位返回0)
    // ========================================================================
    always @(*) begin
        reg_rd_data = reg_array[reg_rd_addr];
    end

    // ========================================================================
    // 特殊处理: soft_reset (0x00 bit7) - 自清除脉冲
    // ========================================================================
    reg soft_reset_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_array[8'h00][7] <= 1'b0;
            soft_reset_d <= 1'b0;
        end else begin
            soft_reset_d <= 1'b0;
            if (reg_wr_en && (reg_wr_addr == 8'h00) && reg_wr_data[7]) begin
                reg_array[8'h00][7] <= 1'b0;  // 自清除
                soft_reset_d <= 1'b1;          // 1clk脉冲
            end
        end
    end
    assign soft_reset = soft_reset_d;

    // ========================================================================
    // 特殊处理: clear_fault (0x21 bit7) - 自清除脉冲
    // ========================================================================
    reg clear_fault_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_array[8'h21][7] <= 1'b0;
            clear_fault_d <= 1'b0;
        end else begin
            clear_fault_d <= 1'b0;
            if (reg_wr_en && (reg_wr_addr == 8'h21) && reg_wr_data[7]) begin
                reg_array[8'h21][7] <= 1'b0;  // 自清除
                clear_fault_d <= 1'b1;          // 1clk脉冲
            end
        end
    end
    assign clear_fault_pulse = clear_fault_d;

    // ========================================================================
    // 组合逻辑: 寄存器位域提取
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
    assign dc_ldg_abort = reg_array[8'h09][7];  // 修复#1
    assign ldg_bypass   = reg_array[8'h09][0];
    assign ldg_lo_enable = reg_array[8'h09][1];
    assign dc_ramp_settle = {reg_array[8'h09][6], reg_array[8'h09][5]};
    assign pin_ctrl     = reg_array[8'h14];
    assign ac_diag_en   = reg_array[8'h15][3:0];
    assign otsd_auto_recovery = reg_array[8'h21][3];
    assign phase_sel_msb = reg_array[8'h28][5];

endmodule
