// слейв APB - устройство, к которому обращается мастер.
module apb_slave
(
  input pclk,                  // синхросигнал
  input presetn,               // сигнал сброса (инверсный)
  input [31:0] paddr,          // адрес обращения
  input [31:0] pwdata,         // данные для записи
  input psel,                  // признак выбора устройства
  input penable,               // признак активной транзакции
  input pwrite,                // признак операции записи
  output logic pready,         // признак готовности от устройства
  output logic pslverr,        // опциональный сигнал: признак ошибки при обращении
  output logic [31:0] prdata   // прочитанные данные
);

logic [31:0] register_with_some_name;   // 32-битный регистр по адресу 0x0

//APB FSM - конечный автомат, у него 3 состояния
enum logic [1:0] {
  APB_SETUP,      // ждем, когда мастер начнет обмен
  APB_W_ENABLE,   // выполняем запись
  APB_R_ENABLE    // выполняем чтение
} apb_st;         // apb_st - переменная, где хранится текущее состояние

always @(posedge pclk)   // все действия выполняются по фронту тактового сигнала
if (!presetn)            // если сброс (presetn = 0)
begin
  // обнуляем выходы и регистр, автомат в начальное состояние
  prdata <= '0;
  pslverr <= 1'b0;
  pready <= 1'b0;
  register_with_some_name <= 32'h0;
  apb_st <= APB_SETUP;
end
else                     // если сброса нет - работаем
begin
  case(apb_st)           // смотрим, в каком состоянии автомат
    APB_SETUP:
    begin: apb_setup_st
      // clear the prdata and error
      prdata <= '0;
      pready <= 1'b0;
      pslverr <= 1'b0;   // исправлено: ошибку тоже сбрасываем, в заготовке ее не сбрасывали
      // Move to ENABLE when the psel is asserted
      if (psel && !penable)       // мастер выбрал нас (psel = 1), первая фаза
      begin
        if (pwrite == 1'b1)       // если запись
        begin
          apb_st <= APB_W_ENABLE; // переходим в состояние записи
        end
        else                      // иначе чтение
        begin
          apb_st <= APB_R_ENABLE; // переходим в состояние чтения
        end
      end
    end: apb_setup_st

    APB_W_ENABLE:                 // состояние записи
    begin: apb_w_en_st
      // decode address and write
      if (psel && penable && pwrite)   // вторая фаза записи
      begin
        pready <= 1'b1;                // говорим мастеру, что готовы
        case (paddr[7:0])              // смотрим младшие 8 бит адреса
          8'h0: begin
            // запись в регистр со смещением 0
            // исправлено: значение зависит от младшего бита данных pwdata[0]
            if (pwdata[0] == 1'b0)
              register_with_some_name <= 32'hAAAA_AAAA;   // бит 0 = 0
            else
              register_with_some_name <= 32'h5555_5555;   // бит 0 = 1
            // исправлено: сообщение о записи
            $display("[%0t] SLAVE: write 0x%h to addr 0x%h", $time, pwdata, paddr);
          end
          8'h4: begin
            // запись в регистр со смещением 4 (пока регистра нет)
            $display("[%0t] SLAVE: write 0x%h to addr 0x%h", $time, pwdata, paddr);
          end
          8'h8: begin
            // запись в регистр со смещением 8 (пока регистра нет)
            $display("[%0t] SLAVE: write 0x%h to addr 0x%h", $time, pwdata, paddr);
          end
          default:                     // любой другой адрес - такого регистра нет
          begin
            pslverr <= 1'b1;           // выставляем ошибку
            $display("[%0t] SLAVE: error, wrong addr 0x%h", $time, paddr);
          end
        endcase
        apb_st <= APB_SETUP;           // запись закончена, возвращаемся в начало
      end
    end: apb_w_en_st

    APB_R_ENABLE:                 // состояние чтения
    begin: apb_r_en_st
      if (psel && penable && !pwrite)  // вторая фаза чтения
      begin
        pready <= 1'b1;                // готовы
        case (paddr[7:0])
          8'h0: begin
            // чтение из регистра со смещением 0
            prdata[31:0] <= register_with_some_name[31:0];   // отдаем значение регистра мастеру
            $display("[%0t] SLAVE: read addr 0x%h, data 0x%h", $time, paddr, register_with_some_name);
          end
          8'h4: begin
            // чтение из регистра со смещением 4 (пока регистра нет)
            $display("[%0t] SLAVE: read addr 0x%h", $time, paddr);
          end
          8'h8: begin
            // чтение из регистра со смещением 8 (пока регистра нет)
            $display("[%0t] SLAVE: read addr 0x%h", $time, paddr);
          end
          default:                     // неверный адрес
          begin
            pslverr <= 1'b1;
            $display("[%0t] SLAVE: error, wrong addr 0x%h", $time, paddr);
          end
        endcase
        apb_st <= APB_SETUP;           // чтение закончено
      end
    end: apb_r_en_st

    default:                      // если автомат вдруг в неизвестном состоянии
    begin
      pslverr <= 1'b1;
      apb_st <= APB_SETUP;        // исправлено: возвращаемся в начальное состояние
    end
  endcase

  // исправлено: в заготовке был блок, который каждый такт
  // перезаписывал регистр по его старому биту 0, из-за него записанное
  // значение сразу затиралось и регистр всегда был AAAA_AAAA, сейчас блок убран
end

endmodule