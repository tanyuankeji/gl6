/**
 * Module: i2c_slave
 * Description: I2C从机接口模块
 *              支持标准模式(100kHz)和快速模式(400kHz)
 *              支持7位地址+R/W位，单字节写、顺序写、随机读、顺序读
 *              地址由i2c_addr1/i2c_addr0引脚选择（4个地址选项）
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Parameters:
 *   - CLK_FREQ: 系统时钟频率Hz（默认10MHz）
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位，低有效
 *   - scl: I2C时钟线（输入采样）
 *   - sda_i: I2C数据线输入
 *   - sda_o: I2C数据线输出（需外部三态）
 *   - sda_oe: I2C数据线输出使能
 *   - i2c_addr1: I2C地址选择位1
 *   - i2c_addr0: I2C地址选择位0
 *   - reg_wr_en: 寄存器写使能（I2C写入完成一个字节）
 *   - reg_wr_addr: 寄存器写地址
 *   - reg_wr_data: 寄存器写数据
 *   - reg_rd_en: 寄存器读使能
 *   - reg_rd_addr: 寄存器读地址
 *   - reg_rd_data: 寄存器读数据（来自register_file）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module i2c_slave #(
    parameter CLK_FREQ = 10_000_000   // 系统时钟频率，默认10MHz
) (
    input  wire        clk,
    input  wire        rst_n,

    // I2C总线接口
    input  wire        scl,           // I2C时钟线（从主机输入）
    input  wire        sda_i,         // I2C数据线输入
    output reg         sda_o,         // I2C数据线输出
    output reg         sda_oe,        // I2C数据线输出使能（1=驱动SDA）

    // I2C地址选择
    input  wire        i2c_addr1,     // 地址选择位1
    input  wire        i2c_addr0,     // 地址选择位0

    // 寄存器访问接口
    output reg         reg_wr_en,     // 寄存器写使能脉冲
    output reg  [7:0]  reg_wr_addr,   // 寄存器写地址
    output reg  [7:0]  reg_wr_data,   // 寄存器写数据
    output reg         reg_rd_en,     // 寄存器读使能脉冲
    output reg  [7:0]  reg_rd_addr,   // 寄存器读地址
    input  wire [7:0]  reg_rd_data    // 寄存器读数据返回
);

    //----------------------------------------------------------
    // I2C状态机状态定义
    //----------------------------------------------------------
    localparam I2C_IDLE      = 4'd0;  // 空闲，等待START
    localparam I2C_ADDR      = 4'd1;  // 接收7位地址+R/W
    localparam I2C_ACK_ADDR  = 4'd2;  // 发送地址ACK
    localparam I2C_WR_ADDR   = 4'd3;  // 接收寄存器地址字节
    localparam I2C_ACK_WA    = 4'd4;  // 发送寄存器地址ACK
    localparam I2C_WR_DATA   = 4'd5;  // 接收数据字节
    localparam I2C_ACK_WD    = 4'd6;  // 发送数据ACK
    localparam I2C_RD_DATA   = 4'd7;  // 发送数据字节
    localparam I2C_ACK_RD    = 4'd8;  // 接收读ACK/NACK

    //----------------------------------------------------------
    // 内部寄存器
    //----------------------------------------------------------
    reg [3:0]   state_reg;            // 当前状态
    reg [3:0]   state_next;           // 下一状态（组合逻辑）

    reg         scl_reg;              // SCL同步寄存器1
    reg         scl_prev;             // SCL上一拍（边沿检测）
    reg         sda_reg;              // SDA同步寄存器
    reg         sda_prev;             // SDA上一拍（边沿检测）

    reg [3:0]   bit_cnt_reg;          // 位计数器（0-7）
    reg [7:0]   addr_byte_reg;        // 接收的地址字节
    reg [7:0]   reg_addr_reg;         // 当前寄存器地址
    reg [7:0]   rd_data_reg;          // 读数据锁存

    reg         is_read_reg;          // 读写标志：1=读操作，0=写操作
    reg         addr_match_reg;       // 地址匹配标志

    //----------------------------------------------------------
    // SCL/SDA同步与边沿检测
    // 双FF同步消除亚稳态，边沿检测产生上升/下降沿脉冲
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_reg  <= 1'b1;         // I2C总线空闲为高
            scl_prev <= 1'b1;
            sda_reg  <= 1'b1;
            sda_prev <= 1'b1;
        end else begin
            scl_reg  <= scl;          // 同步SCL
            scl_prev <= scl_reg;      // 记录SCL上一拍
            sda_reg  <= sda_i;        // 同步SDA
            sda_prev <= sda_reg;      // 记录SDA上一拍
        end
    end

    // SCL上升沿脉冲：在SCL由低变高时产生一个周期的脉冲
    wire scl_rising  = scl_reg & ~scl_prev;
    // SCL下降沿脉冲：在SCL由高变低时产生一个周期的脉冲
    wire scl_falling = ~scl_reg & scl_prev;

    //----------------------------------------------------------
    // START/STOP条件检测
    // START: SCL为高时SDA产生下降沿
    // STOP:  SCL为高时SDA产生上升沿
    //----------------------------------------------------------
    wire start_det = scl_reg & ~sda_reg & sda_prev;   // SCL高+SDA下降沿
    wire stop_det  = scl_reg & sda_reg & ~sda_prev;    // SCL高+SDA上升沿

    //----------------------------------------------------------
    // I2C从机地址生成（7位地址，由addr1/addr0选择低2位）
    // 基地址0x6A = 1101010，addr1/addr0替换最低2位
    //----------------------------------------------------------
    wire [6:0] i2c_slave_addr = {3'b110, 1'b0, 1'b1, i2c_addr1, i2c_addr0};

    //----------------------------------------------------------
    // 状态寄存器（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= I2C_IDLE;
        end else begin
            // START条件在任何状态下都重新开始地址接收
            if (start_det) begin
                state_reg <= I2C_ADDR;
            // STOP条件回到空闲
            end else if (stop_det) begin
                state_reg <= I2C_IDLE;
            // SCL上升沿时推进状态机
            end else if (scl_rising) begin
                state_reg <= state_next;
            end
        end
    end

    //----------------------------------------------------------
    // 下一状态组合逻辑
    //----------------------------------------------------------
    always @(*) begin
        // 默认保持当前状态
        state_next = state_reg;

        case (state_reg)
            I2C_IDLE: begin
                // 空闲态，等待START（由start_det在上层处理）
                state_next = I2C_IDLE;
            end

            I2C_ADDR: begin
                // 接收8位地址+R/W，在第8个SCL上升沿后转到ACK
                if (bit_cnt_reg == 4'd7) begin
                    state_next = I2C_ACK_ADDR;
                end
            end

            I2C_ACK_ADDR: begin
                // 地址ACK后，根据R/W位和地址匹配决定下一步
                if (addr_match_reg) begin
                    if (is_read_reg) begin
                        // 读操作：准备发送数据
                        state_next = I2C_RD_DATA;
                    end else begin
                        // 写操作：先接收寄存器地址
                        state_next = I2C_WR_ADDR;
                    end
                end else begin
                    // 地址不匹配，回到空闲
                    state_next = I2C_IDLE;
                end
            end

            I2C_WR_ADDR: begin
                // 接收8位寄存器地址
                if (bit_cnt_reg == 4'd7) begin
                    state_next = I2C_ACK_WA;
                end
            end

            I2C_ACK_WA: begin
                // 寄存器地址ACK后，进入数据接收
                state_next = I2C_WR_DATA;
            end

            I2C_WR_DATA: begin
                // 接收8位数据
                if (bit_cnt_reg == 4'd7) begin
                    state_next = I2C_ACK_WD;
                end
            end

            I2C_ACK_WD: begin
                // 数据ACK后，继续接收下一字节（顺序写）
                // 或主机发送STOP结束传输
                state_next = I2C_WR_DATA;
            end

            I2C_RD_DATA: begin
                // 发送8位数据
                if (bit_cnt_reg == 4'd7) begin
                    state_next = I2C_ACK_RD;
                end
            end

            I2C_ACK_RD: begin
                // 主机ACK：继续读下一字节（顺序读）
                // 主机NACK：等待STOP
                state_next = I2C_RD_DATA;
            end

            default: state_next = I2C_IDLE;
        endcase
    end

    //----------------------------------------------------------
    // 位计数器（时序逻辑）
    // 每接收/发送8位后复位
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt_reg <= 4'd0;
        end else begin
            if (start_det) begin
                bit_cnt_reg <= 4'd0;       // START复位计数器
            end else if (scl_rising) begin
                if (state_reg == I2C_ADDR   ||
                    state_reg == I2C_WR_ADDR ||
                    state_reg == I2C_WR_DATA ||
                    state_reg == I2C_RD_DATA) begin
                    if (bit_cnt_reg == 4'd7) begin
                        bit_cnt_reg <= 4'd0;
                    end else begin
                        bit_cnt_reg <= bit_cnt_reg + 4'd1;
                    end
                end else begin
                    bit_cnt_reg <= 4'd0;   // ACK状态复位计数器
                end
            end
        end
    end

    //----------------------------------------------------------
    // 地址字节接收与匹配（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_byte_reg   <= 8'd0;
            is_read_reg     <= 1'b0;
            addr_match_reg  <= 1'b0;
        end else begin
            if (start_det) begin
                addr_byte_reg   <= 8'd0;
                addr_match_reg  <= 1'b0;
            end else if (scl_rising && state_reg == I2C_ADDR) begin
                // 在地址接收阶段，逐位移入
                addr_byte_reg <= {addr_byte_reg[6:0], sda_reg};
                // 最后一位接收完毕后判断地址匹配
                if (bit_cnt_reg == 4'd7) begin
                    is_read_reg    <= sda_reg;              // R/W位
                    // 比较高7位地址
                    addr_match_reg <= (addr_byte_reg[6:0] == i2c_slave_addr);
                end
            end
        end
    end

    //----------------------------------------------------------
    // 寄存器地址接收（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_addr_reg <= 8'd0;
        end else begin
            if (scl_rising && state_reg == I2C_WR_ADDR) begin
                // 逐位移入寄存器地址
                reg_addr_reg <= {reg_addr_reg[6:0], sda_reg};
            end
        end
    end

    //----------------------------------------------------------
    // 写数据接收 + 写使能生成（时序逻辑）
    //----------------------------------------------------------
    reg [7:0] wr_data_reg;   // 写数据缓存

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_data_reg <= 8'd0;
            reg_wr_en   <= 1'b0;
            reg_wr_addr <= 8'd0;
            reg_wr_data <= 8'd0;
        end else begin
            reg_wr_en <= 1'b0;   // 默认拉低，仅产生一个周期脉冲
            if (scl_rising && state_reg == I2C_WR_DATA) begin
                wr_data_reg <= {wr_data_reg[6:0], sda_reg};
            end
            // 在ACK_WD状态的第一个SCL上升沿触发写操作
            // 此时8位数据已完整接收
            if (scl_falling && state_reg == I2C_ACK_WD && bit_cnt_reg == 4'd0) begin
                reg_wr_en   <= 1'b1;
                reg_wr_addr <= reg_addr_reg;
                reg_wr_data <= {wr_data_reg[6:0], sda_reg};
                // 顺序写：地址自增
                reg_addr_reg <= reg_addr_reg + 8'd1;
            end
        end
    end

    //----------------------------------------------------------
    // 读数据发送 + 读使能生成（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_rd_en   <= 1'b0;
            reg_rd_addr <= 8'd0;
            rd_data_reg <= 8'd0;
        end else begin
            reg_rd_en <= 1'b0;   // 默认拉低
            // 进入RD_DATA前发起读请求
            if (scl_falling && state_next == I2C_RD_DATA && state_reg == I2C_ACK_ADDR) begin
                reg_rd_en   <= 1'b1;
                reg_rd_addr <= reg_addr_reg;
            end
            // 顺序读：每次ACK后读下一地址
            if (scl_falling && state_next == I2C_RD_DATA && state_reg == I2C_ACK_RD) begin
                reg_rd_en   <= 1'b1;
                reg_rd_addr <= reg_addr_reg;
                reg_addr_reg <= reg_addr_reg + 8'd1;
            end
            // 锁存读数据
            if (reg_rd_en) begin
                rd_data_reg <= reg_rd_data;
            end
        end
    end

    //----------------------------------------------------------
    // SDA输出驱动（时序逻辑）
    // 在ACK阶段和读数据阶段驱动SDA
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_o   <= 1'b1;
            sda_oe  <= 1'b0;
        end else begin
            // 默认释放SDA（高阻，上拉为高）
            sda_o  <= 1'b1;
            sda_oe <= 1'b0;

            case (state_reg)
                I2C_ACK_ADDR: begin
                    // 地址匹配时拉低SDA发送ACK
                    if (addr_match_reg) begin
                        sda_o  <= 1'b0;
                        sda_oe <= 1'b1;
                    end
                end

                I2C_ACK_WA: begin
                    // 寄存器地址ACK
                    sda_o  <= 1'b0;
                    sda_oe <= 1'b1;
                end

                I2C_ACK_WD: begin
                    // 写数据ACK
                    sda_o  <= 1'b0;
                    sda_oe <= 1'b1;
                end

                I2C_RD_DATA: begin
                    // 读数据阶段：在SCL低时改变SDA
                    if (scl_falling || (scl_reg == 1'b0 && scl_prev == 1'b0)) begin
                        sda_oe <= 1'b1;
                        // MSB先发，根据bit_cnt选择对应位
                        sda_o  <= rd_data_reg[7 - bit_cnt_reg[2:0]];
                    end
                end

                I2C_ACK_RD: begin
                    // 读ACK阶段：释放SDA等待主机ACK/NACK
                    // 如果主机NACK(sda_reg=1)，准备结束传输
                    sda_oe <= 1'b0;
                end

                default: begin
                    sda_o   <= 1'b1;
                    sda_oe  <= 1'b0;
                end
            endcase
        end
    end

endmodule
