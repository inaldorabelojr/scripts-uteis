declare
  v_sql_count        number;
  v_regra            varchar2(2);  
  v_data_ini         date;
  v_data_ini_mes_ant date;
  v_data_fim         date;
  v_data_fim_mes_ant date;
  v_perido           number(6);
  
begin
  dbms_application_info.set_client_info('Relatorio Rodolfo');
  --execute immediate 'truncate table inaldo_rabelo.tmp_transito';

  for ano in 2020..to_number(to_char(sysdate,'yyyy')) loop
      for mes in 01..12 loop
          dbms_application_info.set_action(ano||lpad(mes,2,0));
          
          v_perido:=ano||lpad(mes,2,0);
          
          if v_perido >= 201406 and v_perido<=to_number(to_char(sysdate,'yyyymm')) then
              v_data_ini := TO_DATE( ano||lpad(mes,2,0),'yyyymm');
              v_data_fim := LAST_DAY(TO_DATE(ano||lpad(mes,2,0),'yyyymm'));
              
              v_data_ini         := TO_DATE(to_char(v_data_ini,'SYYYY-MM-DD')||' 00:00:00', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN');
              v_data_ini_mes_ant := add_months(trunc(v_data_ini),-1);
              v_data_fim         := TO_DATE(to_char(v_data_fim,'SYYYY-MM-DD')||' 23:59:59', 'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN');
              v_data_fim_mes_ant := add_months(trunc(v_data_fim),-1);
              
              --dbms_output.put_line(v_data_ini||' --> '||v_data_fim);
              dbms_output.put_line(to_char(v_data_ini,'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN')||' --> '||to_char(v_data_fim,'SYYYY-MM-DD HH24:MI:SS', 'NLS_CALENDAR=GREGORIAN'));
              
          end if;
      end loop;
  end loop;
end;
