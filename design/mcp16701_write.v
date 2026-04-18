`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Hariram 
// 
// Create Date: 04/18/2026 07:35:52 PM
// Design Name: 
// Module Name: mcp16701_write
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: trying to make only write to the pmic rad operation is not possible  dervied form the i2c top 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module mcp16701_write
(
    input clk,
    input reset,

    input start,
    input read,
    input write,

    input [15:0] reg_addr,
    input [7:0] write_data,

    output reg [7:0] read_data,
    output reg done,

    output scl,
    inout sda
);

parameter MCP16701_ADDR = 7'h5B; // typical address

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
           REG_ADDR_H    = 3,
           REG_ADDR_L    = 4,
           WRITE_DATA    = 5,
           RESTART_CMD   = 6,
           DEV_ADDR_R    = 7,
           READ_DATA     = 8,
           STOP_CMD      = 9,
           DONE          = 10;

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

//wr_i2c <= 0; //commented by hariram need to check tomorrow 
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
    din <= {MCP16701_ADDR,1'b0};//write mode
    wr_i2c <= 1;
    state <= REG_ADDR_H;
end
//--------------------------------------------------

REG_ADDR_H:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= reg_addr[15:8];
    wr_i2c <= 1;
    state <= REG_ADDR_L;
end

//--------------------------------------------------

REG_ADDR_L:
if(done_tick)
begin
    cmd <= 3'b001;
    din <= reg_addr[7:0];
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