`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ECIS,IISc
// Engineer: Hariram P derived from https://github.com/aseddin/ece_4305/blob/main/M15%20to%20M18%20-%20Complete%20System/HDL/i2c_master.sv
// 
// Create Date: 03/05/2026 03:27:12 PM
// Design Name: 
// Module Name: i2c_top
// Project Name: 
// Target Devices: neso a7
// Tool Versions: 2025.1
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mcp16701_i2c_top
(
    input clk,
    input reset,

    input start,
    input read,
    input write,

    input [7:0] reg_addr,
    input [7:0] write_data,

    output reg [7:0] read_data,
    output reg done,

    output scl,
    inout sda
);

parameter MCP16701_ADDR = 7'h60; // typical address

// i2c master signals
reg [7:0] din;
reg [2:0] cmd;
reg wr_i2c;

wire ready;
wire done_tick;
wire ack;
wire [7:0] dout;

wire [15:0] dvsr = 16'd250; // adjust for desired I2C speed

//--------------------------------------------------
// instantiate master
//--------------------------------------------------

i2c_master i2c0
(
    .clk(clk),
    .reset(reset),
    .din(din),
    .dvsr(dvsr),
    .cmd(cmd),
    .wr_i2c(wr_i2c),
    .scl(scl),
    .sda(sda),
    .ready(ready),
    .done_tick(done_tick),
    .ack(ack),
    .dout(dout)
);

//--------------------------------------------------
// FSM
//--------------------------------------------------

localparam IDLE          = 0,
           START_CMD     = 1,
           DEV_ADDR_W    = 2,
           REG_ADDR      = 3,
           WRITE_DATA    = 4,
           RESTART_CMD   = 5,
           DEV_ADDR_R    = 6,
           READ_DATA     = 7,
           STOP_CMD      = 8,
           DONE          = 9;

reg [3:0] state;

//--------------------------------------------------

always @(posedge clk or posedge reset)
begin

if(reset)
begin
    state <= IDLE;
    wr_i2c <= 0;
    done <= 0;
end

else
begin

wr_i2c <= 0;
done <= 0;

case(state)

IDLE:
begin
    if(start)
        state <= START_CMD;
end

//--------------------------------------------------

START_CMD:
if(ready)
begin
    cmd <= 3'b000;
    wr_i2c <= 1;
    state <= DEV_ADDR_W;
end

//--------------------------------------------------

DEV_ADDR_W:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= {MCP16701_ADDR,1'b0};
    wr_i2c <= 1;
    state <= REG_ADDR;
end

//--------------------------------------------------

REG_ADDR:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= reg_addr;
    wr_i2c <= 1;

    if(write)
        state <= WRITE_DATA;
    else
        state <= RESTART_CMD;
end

//--------------------------------------------------

WRITE_DATA:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= write_data;
    wr_i2c <= 1;
    state <= STOP_CMD;
end

//--------------------------------------------------

RESTART_CMD:
if(done_tick)
begin
    cmd <= 3'b100;
    wr_i2c <= 1;
    state <= DEV_ADDR_R;
end

//--------------------------------------------------

DEV_ADDR_R:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= {MCP16701_ADDR,1'b1};
    wr_i2c <= 1;
    state <= READ_DATA;
end

//--------------------------------------------------

READ_DATA:
if(done_tick)
begin
    cmd <= 3'b010;
    din <= 8'b00000001; // NACK after 1 byte
    wr_i2c <= 1;
    read_data <= dout;
    state <= STOP_CMD;
end

//--------------------------------------------------

STOP_CMD:
if(done_tick)
begin
    cmd <= 3'b011;
    wr_i2c <= 1;
    state <= DONE;
end

//--------------------------------------------------

DONE:
if(done_tick)
begin
    done <= 1;
    state <= IDLE;
end

//--------------------------------------------------

endcase

end
end

endmodule