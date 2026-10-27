// модуль верхнего уровня (testbench)
`timescale 1ns/1ps   

module tb_top;       

// провода шины APB между мастером и слейвом
logic pclk;            // тактовый сигнал
logic presetn;         // сброс
logic psel;
logic penable;
logic pwrite;
logic [31:0] paddr;
logic [31:0] pwdata;
wire [31:0] prdata;    // wire - эти сигналы выдает слейв
wire pready;
wire pslverr;

parameter p_device_offset = 32'h7000_0000;   // адрес, где находится наш слейв

logic [31:0] address;            // адрес для обращения
logic [31:0] data_to_device;     // что записываем
logic [31:0] data_from_device;   // что прочитали
int errors = 0;                  // счетчик ошибок

// мои данные для записи (п.9)
parameter NUM     = 32'd11;          // номер в списке группы (11 в десятичной)
parameter DATE    = 32'h1607_2004;   // дата 16.07.2004, записана цифрами в hex
parameter SURNAME = "Tokm";          // первые 4 буквы фамилии, каждая буква = 1 байт ASCII
parameter NAME    = "Nade";          // первые 4 буквы имени

// подключаем мастер
// запись .pclk значит, что порт pclk соединяется с проводом pclk
apb_master master
(
  .pclk, .presetn,
  .psel, .penable, .pwrite, .paddr, .pwdata,
  .prdata, .pready, .pslverr
);

// подключаем слейв, DUT - тестируемое устройство
apb_slave DUT
(
  .pclk(pclk),         // синхросигнал
  .presetn,            // сигнал сброса (инверсный)
  .paddr(paddr),       // адрес обращения
  .pwdata(pwdata),     // данные для записи
  .psel(psel),         // признак выбора устройства
  .penable(penable),   // признак активной транзакции
  .pwrite(pwrite),     // признак операции записи
  .pready(pready),     // признак готовности от устройства
  .pslverr(pslverr),   // признак ошибки при обращении
  .prdata(prdata)      // прочитанные данные
);

// задача проверки: сравниваем прочитанное значение с ожидаемым
task check(input logic [31:0] addr, input logic [31:0] expected, input logic [31:0] actual);
  if (actual === expected)          // === сравнивает в том числе неопределенные биты x
    $display("OK:     addr 0x%h = 0x%h", addr, actual);
  else begin
    $display("ERROR:  addr 0x%h = 0x%h, expected 0x%h", addr, actual, expected);
    errors++;                       // увеличиваем счетчик ошибок на 1
  end
endtask

// тактовый сигнал: каждые 10 нс меняется на противоположный, период 20 нс
always
  #10ns pclk = ~pclk;

// основной тест
initial
begin
  $timeformat(-9, 0, " ns", 8);   // время в сообщениях будет в нс
  pclk = 0;
  presetn = 1'b1;
  repeat (5) @(posedge pclk);     // ждем 5 тактов
  presetn = 1'b0;                 // включаем сброс
  repeat (5) @(posedge pclk);
  presetn = 1'b1;                 // выключаем сброс
  repeat (5) @(posedge pclk);

  // п.8: пишем 12345678 (младший бит 0) по адресу 0, должно прочитаться AAAAAAAA
  address = p_device_offset + 0;
  data_to_device = 32'h12345678;
  master.apb_write(address, data_to_device);    // вызываем задачу записи из мастера
  master.apb_read(address, data_from_device);   // вызываем задачу чтения
  $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
  check(address, 32'hAAAA_AAAA, data_from_device);

  // пишем 1 (младший бит 1), должно прочитаться 55555555
  data_to_device = 32'h1;
  master.apb_write(address, data_to_device);
  master.apb_read(address, data_from_device);
  $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
  check(address, 32'h5555_5555, data_from_device);

  // п.9: записываем свои данные по адресам 0x0, 0x4, 0x8, 0xC
  master.apb_write(p_device_offset + 32'h0, NUM);
  master.apb_write(p_device_offset + 32'h4, DATE);
  master.apb_write(p_device_offset + 32'h8, SURNAME);
  master.apb_write(p_device_offset + 32'hC, NAME);

  // читаем обратно и проверяем
  master.apb_read(p_device_offset + 32'h0, data_from_device);
  check(p_device_offset + 32'h0, 32'h5555_5555, data_from_device);  // 11 нечетное, бит 0 = 1
  master.apb_read(p_device_offset + 32'h4, data_from_device);
  check(p_device_offset + 32'h4, DATE, data_from_device);
  master.apb_read(p_device_offset + 32'h8, data_from_device);
  check(p_device_offset + 32'h8, SURNAME, data_from_device);
  master.apb_read(p_device_offset + 32'hC, data_from_device);
  check(p_device_offset + 32'hC, NAME, data_from_device);

  // пишем по адресу, которого нет - слейв должен выставить ошибку pslverr
  master.apb_write(p_device_offset + 32'h10, 32'h0);

  // итог
  if (errors == 0)
    $display("TEST PASSED");
  else
    $display("TEST FAILED, errors: %0d", errors);

  repeat (10) @(posedge pclk);
  $stop();                        // остановка моделирования
end

// $monitor выводит строку каждый раз, когда меняется какой-то из сигналов
initial
begin
  $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h",
           penable, pready, paddr, pwdata, prdata);
end

endmodule
