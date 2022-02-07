create or replace function f_converter_decimal_em_tempo(p_valor_decimal in number ) return  varchar2 is
    
  v_dia    number;
  v_hora   number;
  v_min    number;
  v_seg    number;
  v_aux    number;
                        
  v_retorno varchar2(32);
begin
  execute immediate 'alter session set nls_numeric_characters = '',.''';
    
  /*p_valor_decimal = data final - data inicial*/
    
  v_aux := round(to_number((p_valor_decimal)*24*60*60)); --Tempo total em Segundos
    
  --Segundos
  v_min := trunc(v_aux/60);
           --dbms_output.put_line(v_min);
           --dbms_output.put_line(v_aux);           
           --dbms_output.put_line(v_min*60);
  v_seg := replace(trunc((v_aux)-(v_min*60)),60,0);
    
  --Minutos
  v_hora := trunc(v_aux/60/60);
  v_min := trunc(((v_aux/60/60)-v_hora)*60);
           --dbms_output.put_line(v_min);
           --dbms_output.put_line(v_hora);
    
  --Horas
  v_dia := trunc(v_aux/60/60/24);
           --dbms_output.put_line(v_dia);
           --dbms_output.put_line(v_aux/60/60/24);
  v_hora := trunc((v_hora-(v_dia*24)));
  v_dia := (case when v_dia=0 then '' else v_dia end);
    
  v_retorno := trim(v_dia||' '||lpad(v_hora,2,'0')||':'||lpad(v_min,2,'0')||':'||lpad(v_seg,2,'0'));
                          
  return v_retorno;
end;
