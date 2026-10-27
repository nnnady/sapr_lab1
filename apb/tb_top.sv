// модуль верхнего уровня (testbench)
// здесь соединяются мастер и слейв, задается тактовый сигнал и сброс,
// и запускается проверка
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

  // пишем 12345678 (младший бит 0) по адресу 0, потом читаем
  // должно прочитаться AAAAAAAA
  address = p_device_offset + 0;
  data_to_device = 32'h12345678;
  master.apb_write(address, data_to_device);    // вызываем задачу записи из мастера
  master.apb_read(address, data_from_device);   // вызываем задачу чтения
  $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);

  // пишем 1 (младший бит 1), должно прочитаться 55555555
  data_to_device = 32'h1;
  master.apb_write(address, data_to_device);
  master.apb_read(address, data_from_device);
  $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);

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
