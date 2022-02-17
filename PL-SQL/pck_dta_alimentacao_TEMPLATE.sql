create or replace package pck_alimentacao is

    procedure stp_montar_sql(p_dir_orig      varchar2, 
                             p_nome_arquivo  varchar2, 
                             p_nome_tabela   varchar2, 
                             p_prefixo_campo varchar2);
                             
    procedure stp_le_arquivo(p_dir_orig      varchar2,
                             p_nome_arquivo  varchar2,
                             p_ano number);
end;
/
create or replace package body pck_alimentacao is

  type t_strings is table of varchar2(700) index by binary_integer;
  
function fnc_valida_numero(p_numero varchar2) return number is

v_numero number;
v_result number;

begin
    begin
        v_numero := to_number(p_numero);
        v_result := 1;
    exception when OTHERS then
        v_result := 0;
    end;
    -- 1 - é numero || 0 - não é numero
    return v_result;
end;

function fnc_valida_data(p_data varchar2) return number is

v_data varchar(30);
v_result number;

begin
    begin
        if instr(p_data,'/') = 3 then
            v_data := to_date(p_data, 'dd/mm/yyyy');
            --v_data := to_date(p_data, 'dd/mm/yy');
            v_result := 1;
        else
            v_result := 0;
        end if;
    exception when OTHERS then
        v_result := 0;
    end;
    -- 1 - é data || 0 - não é data
    return v_result;
end;

function fnc_tratar_nome_coluna(p_nome_coluna varchar2) return varchar2 is

vnova_string varchar2(4000); 

begin
  
  vnova_string := trim(translate(p_nome_coluna,
                       'ÁÇÉÍÓÚÀÈÌÒÙÂÊÎÔÛÃÕËÜáçéíóúàèìòùâêîôûãõëü ?.()/',
                       'ACEIOUAEIOUAEIOUAOEUaceiouaeiouaeiouaoeu_'));
                       
  vnova_string := upper(replace(vnova_string,'Nº','NUM'));                     

  return vnova_string;
end;  

procedure carregarArray(p_linha in varchar2,p_array in out t_strings, v_index out number) is
  v_posicao number;
  v_linha varchar2(5000);
begin
  v_index := 1;
  v_linha:= p_linha;
  v_posicao := inStr(v_linha,';');
      
  while (v_posicao > 0) loop
      p_array(v_index) := substr(v_linha,1,v_posicao - 1);

      v_linha := substr(v_linha,v_posicao + 1);
      v_posicao := nvl(instr(v_linha,';'),0);
      v_index := v_index + 1;
      if v_posicao = 0 then
          p_array(v_index) := v_linha;             
          exit;
      end if;
  end loop;
end;

procedure stp_montar_sql(p_dir_orig      varchar2, 
                         p_nome_arquivo  varchar2, 
                         p_nome_tabela   varchar2, 
                         p_prefixo_campo varchar2) is

  type t_flag is table of boolean index by binary_integer;
  type t_array_string is table of varchar2(10) index by binary_integer;
  type t_array_number is table of number(3) index by binary_integer;
  

  v_arq                   utl_file.file_type;
  v_num_linha             number;

  v_linha                 varchar2(5000);
    
  v_sql                   varchar2(30000);
  v_vetor_reg             varchar2(30000);
  v_sql_comment           varchar2(4000);
  
  v_num_coluna            number := 0;
  v_indice                number; 
  v_campos                t_strings; 
  nome_coluna             t_strings;
  v_comment_col           t_strings;
  v_tam_dados             t_strings;
  v_tipo_dado             t_strings;
  v_flag                  t_flag;
  
  v_parte_inteira         t_array_string;
  v_parte_complementar    t_array_string;
  v_tam_maior             t_array_number;
  v_separador_dec         char(1) := ',';

begin
  
  if v_separador_dec = '.' then
     execute immediate 'alter session set nls_numeric_characters=''.,''';   
  else
     execute immediate 'alter session set nls_numeric_characters='',.''';
     v_separador_dec := ',';
  end if;
   
  -- Abre arquivo txt
  v_arq := utl_file.fopen(p_dir_orig,p_nome_arquivo,'r',32767);

  v_num_linha := 0;
  
  loop
      begin
          utl_file.get_line(v_arq,v_linha);
          v_linha := replace(v_linha,chr(13),null);
          --v_linha := convert(v_linha,'UTF8','WE8ISO8859P1');
          v_num_linha := v_num_linha + 1;
          dbms_application_info.set_action(v_num_linha);
      exception when NO_DATA_FOUND then
          exit;
      end;
          
      carregarArray(v_linha,v_campos, v_indice);
          
      if v_num_linha = 2 then
          for i in 1..v_num_coluna loop
            if instr(v_campos(i),v_separador_dec) > 0 then
               v_parte_inteira(i) := nvl(length(substr(nvl(v_campos(i),0),1,instr(nvl(v_campos(i),0),v_separador_dec)-1)),0);
            else
               v_parte_inteira(i) := length(nvl(v_campos(i),0));
            end if;
            
            v_parte_complementar(i) := '00';
            v_tam_dados(i) := length(nvl(v_campos(i),0))||v_separador_dec||v_parte_complementar(i);
            v_tam_maior(i) := v_parte_inteira(i); 
          end loop;
          
      end if;
       
      if v_num_linha < 2 then
          for i in 1..v_indice loop --recebe numbero de colunas da procedure
              if p_prefixo_campo is null then
                 nome_coluna(i) := rpad(substr(fnc_tratar_nome_coluna(v_campos(i)),1,26),32,' ');
              else
                 nome_coluna(i) := upper(p_prefixo_campo)||'_'||rpad(substr(fnc_tratar_nome_coluna(v_campos(i)),1,26),28,' ');
              end if;
              
              v_comment_col(i) := v_campos(i);
              v_tipo_dado(i) := 'NUMBER';
              v_flag(i) := true;
              v_num_coluna := v_indice; --passa o numero de colunas para a variavel v_num_coluna para que não haja vetores com numero de dados diferentes
          end loop;
          
      else
          for i in 1..v_num_coluna loop --a partir da segund linha do .txt verifica-se o tipo e tamanho dos dados
            
              if length(nvl(v_campos(i),0)) > to_number(v_tam_dados(i)) and v_parte_complementar(i) = '00' then --O tamanho do registro atual é maior que a anterior(tamanhos inteiros)?           
                  v_parte_complementar(i) := '00';
                  v_tam_dados(i) := length(nvl(v_campos(i),0))||v_separador_dec||v_parte_complementar(i);
                                    
              elsif length(substr(nvl(v_campos(i),0),1,instr(nvl(v_campos(i),0),v_separador_dec)-1)) >= to_number(v_parte_inteira(i))
                and v_parte_complementar(i) <> '00' 
                and v_flag(i) = true then --O tamanho do registro atual é maior que a anterior(tamanhos quebrados por virgula)?
                  
                  if instr(v_campos(i),v_separador_dec) > 0 then --verificar se o registro tem separador decimal
                     v_parte_inteira(i) := length(substr(nvl(v_campos(i),0),1,instr(nvl(v_campos(i),0),v_separador_dec)-1));
                  else
                     v_parte_inteira(i) := length(nvl(v_campos(i),0));
                  end if;
                  
                  v_tam_dados(i) := to_number(v_parte_inteira(i)) + to_number(v_parte_complementar(i))||v_separador_dec||v_parte_complementar(i);
                  
                  if v_parte_inteira(i) > v_tam_maior(i) then--se a parte inteira do campo atual for maior que a ultima, variave v_maior_num recebe o esse valor como o maior
                     v_tam_maior(i) := v_parte_inteira(i);
                  end if;
                  
              end if;
              --Se um dos campos nao for data, a flag nao deixa entra na condição de converter o tipo de dado para date
              if v_tipo_dado(i) = 'DATE' and fnc_valida_numero(v_campos(i)) = 1 and v_flag(i) = true and v_campos(i) is not null then
                 if v_parte_complementar(i) <> '00' then --verifica se os registros anteriores eram numericos, adicionando um unidade no tamanho que correponderia ao separador decimal qeu foi subtraido quando era numerico
                      if v_tam_dados(i) < length(v_campos(i)) then
                         v_tam_dados(i) := length(v_campos(i))||v_separador_dec||'00';
                      else  
                         v_tam_dados(i) := v_tam_dados(i) + 1;
                      end if;
                 end if;
                    v_tipo_dado(i) :='VARCHAR2';
                    
                    v_parte_complementar(i) := '00';
                    v_flag(i) := false;
              end if;         
                  
              if (fnc_valida_numero(v_campos(i)) = 0 or fnc_valida_data(v_campos(i)) = 1) and v_flag(i) = true then               
                  if fnc_valida_data(v_campos(i)) = 1 then
                    v_tipo_dado(i) :='DATE';
                  else
                    if v_parte_complementar(i) <> '00' then --verifica se os registros anteriores eram numericos, adicionando um unidade no tamanho que correponderia ao separador decimal qeu foi subtraido quando era numerico
                      if v_tam_dados(i) < length(v_campos(i)) then
                         v_tam_dados(i) := length(v_campos(i))||v_separador_dec||'00';
                      else  
                         v_tam_dados(i) := v_tam_dados(i) + 1;
                      end if;
                      
                    end if;
                    v_tipo_dado(i) :='VARCHAR2';
                    
                    v_parte_complementar(i) := '00';
                    --v_tam_dados(i) := substr(v_tam_dados(i),1,instr(v_tam_dados(i),v_separador_dec))||v_parte_complementar(i);
                    v_flag(i) := false;
                  end if;
                  
              elsif instr(v_campos(i),v_separador_dec) > 0 
                and to_number(v_parte_complementar(i)) < length(substr(v_campos(i),instr(v_campos(i),v_separador_dec)+1))
                and v_flag(i) = true then --se tiver separador decimal e a ultima parte complementar registrada em v_parte_complementar(i) for menor que a do registro atual.                   
                  
                  v_parte_inteira(i) := length(substr(nvl(v_campos(i),0),1,instr(nvl(v_campos(i),0),v_separador_dec)-1));--length(nvl(v_campos(i),0))-1;
                  v_parte_complementar(i) := (length(nvl(v_campos(i),0))-1) - (instr(v_campos(i),v_separador_dec)-1);                
                  if v_tam_maior(i) > to_number(v_parte_inteira(i)) and v_tam_maior(i) <> 0 then --se o maior inteiro for maior que o atual tamanho, usa-se o maior tamanho registrado em v_tam_maior 
                     v_parte_inteira(i) := v_tam_maior(i);
                  end if;
                  
                  v_tam_dados(i) := to_number(v_parte_inteira(i)) + to_number(v_parte_complementar(i))||v_separador_dec||v_parte_complementar(i);
              end if;
              
          end loop;            
      end if;
        
  end loop;
  
  
  utl_file.fclose(v_arq);
  
  --Montar SQL para criação da tabela:
  if v_tipo_dado(1) = 'DATE' then
      v_sql := 'create table '||p_nome_tabela||chr(13)||'('||nome_coluna(1)||v_tipo_dado(1);
      v_vetor_reg := '            v_reg(v_indice).'||nome_coluna(1)||':= to_date(trim(v_campos('||1||')),''dd/mm/yyyy'');';   
  else
      if v_tipo_dado(1) = 'VARCHAR2' then
         v_sql := 'create table '||p_nome_tabela||chr(13)||'('||nome_coluna(1)||v_tipo_dado(1)||'('||substr(v_tam_dados(1),1,instr(v_tam_dados(1),v_separador_dec)-1)||')';
      else
         v_sql := 'create table '||p_nome_tabela||chr(13)||'('||nome_coluna(1)||v_tipo_dado(1)||'('||replace(replace(v_tam_dados(1),'.',','),',00','')||')';
      end if;
      v_vetor_reg := '            v_reg(v_indice).'||nome_coluna(1)||':= trim(v_campos('||1||'));';
  end if;
  
  for i in 2 .. v_num_coluna loop
       if v_tam_dados(i) is null then
          v_tam_dados(i) := '10';
       end if;
       
       if v_tipo_dado(i) = 'DATE' then
         v_sql := v_sql||','||chr(13)||' '||nome_coluna(i)||v_tipo_dado(i);
         v_vetor_reg := v_vetor_reg||chr(13)||'            v_reg(v_indice).'||nome_coluna(i)||':= to_date(trim(v_campos('||i||')),''dd/mm/yyyy'');';
       else
         if v_tipo_dado(i) = 'VARCHAR2' then
            v_sql := v_sql||','||chr(13)||' '||nome_coluna(i)||v_tipo_dado(i)||'('||substr(v_tam_dados(i),1,instr(v_tam_dados(i),v_separador_dec)-1)||')';
         else
            v_sql := v_sql||','||chr(13)||' '||nome_coluna(i)||v_tipo_dado(i)||'('||replace(replace(v_tam_dados(i),'.',','),',00','')||')';
         end if;
         v_vetor_reg := v_vetor_reg||chr(13)||'            v_reg(v_indice).'||nome_coluna(i)||':= trim(v_campos('||i||'));';
       end if;  
          
  end loop;

  v_sql := v_sql||')';
  
  --execute immediate v_sql;
  
  v_sql := v_sql||';'||chr(13);
  
  --Inserir comentários nas colunas da tabela
  for i in 1 .. v_num_coluna loop
      v_sql_comment := '';
      v_sql_comment := v_sql_comment||'comment on column '||p_nome_tabela||'.'||nome_coluna(i)||' is '||''''||v_comment_col(i)||''''; 
      v_sql := v_sql||chr(13)||v_sql_comment||';';
      
      --execute immediate v_sql_comment;
      
  end loop;

  --Imprimir comandos
  dbms_output.put_line(v_sql/*||' - '||length(v_sql)*/);
  dbms_output.put_line('-------------------------------------------------------------------------------------'); 
  dbms_output.put_line(v_vetor_reg);
  
end;

--carregar arquivo
procedure stp_le_arquivo(p_dir_orig varchar2,p_nome_arquivo varchar2, p_ano number) is

v_dir_orig_ora varchar(50);
v_arq          utl_file.file_type;
v_linha        varchar2(5000);
v_num_linha    number;
v_campos       t_strings;
v_indice       number;
v_index        number;

v_separador_dec         char(1) := ',';

                       --Copiar aqui nome da tabela--
type t_reg is table of /*-->*/tabela_destino/*<--*/%rowtype index by binary_integer;
v_reg t_reg;

begin
    execute immediate 'alter session set nls_date_format=''yyyymmdd''';

    if v_separador_dec = '.' then
       execute immediate 'alter session set nls_numeric_characters=''.,''';   
    else
       execute immediate 'alter session set nls_numeric_characters='',.''';
       v_separador_dec := ',';
    end if;
        
    --dbms_application_info.set_client_info('Carga Arq');
    
    begin
        select d.directory_name into v_dir_orig_ora
        from all_directories d
        where d.directory_path = p_dir_orig;
    exception when NO_DATA_FOUND then
        raise_application_error(-20001,'Diretorio ' || p_dir_orig || ' nao encontrado');
    end;
    
    -- Abre arquivo txt
    v_arq := utl_file.fopen(v_dir_orig_ora,p_nome_arquivo,'r',32767);
      
    v_num_linha := 0;
    
    loop
        begin
            utl_file.get_line(v_arq,v_linha);
            v_linha := replace(v_linha,chr(13),null);
            --v_linha := convert(v_linha,'WE8ISO8859P1','UTF8');
            --v_linha := convert(v_linha,'UTF8','WE8ISO8859P1');
            v_num_linha := v_num_linha + 1;
            dbms_application_info.set_action(v_num_linha);
        exception when NO_DATA_FOUND then
            exit;
        end;
        
        if v_num_linha > 1 then
            carregarArray(v_linha,v_campos,v_index);
            
            v_indice := nvl(v_reg.last,0) + 1;
            
            --Copiar aqui nome da tabela array:
            ---------------------------------------------------------------------
            v_reg(v_indice).campo_01  := trim(v_campos(1));
            v_reg(v_indice).campo_02  := trim(v_campos(2));
            v_reg(v_indice).campo_03  := trim(v_campos(3));
            v_reg(v_indice).campo_04  := trim(v_campos(4));
            v_reg(v_indice).campo_05  := trim(v_campos(5));
            v_reg(v_indice).campo_06  := trim(v_campos(6));
            v_reg(v_indice).campo_07  := trim(v_campos(7));
            v_reg(v_indice).campo_08  := trim(v_campos(8));
            v_reg(v_indice).campo_09  := trim(v_campos(9));
            v_reg(v_indice).campo_10  := trim(v_campos(10));
            v_reg(v_indice).campo_11  := trim(v_campos(11));
            v_reg(v_indice).campo_12  := trim(v_campos(12));
            v_reg(v_indice).campo_13  := trim(v_campos(13));
            v_reg(v_indice).campo_14  := trim(v_campos(14));
            v_reg(v_indice).campo_15  := trim(v_campos(15));
            v_reg(v_indice).campo_16  := trim(v_campos(16));
            v_reg(v_indice).campo_17  := trim(v_campos(17));
            v_reg(v_indice).campo_18  := to_date(trim(v_campos(18)),'dd/mm/yyyy');
            v_reg(v_indice).campo_19  := trim(v_campos(19));
            v_reg(v_indice).campo_20  := trim(v_campos(20));
            
            v_reg(v_indice).ANO   := p_ano;
            ---------------------------------------------------------------------
        end if; 
    end loop;
    
    utl_file.fclose(v_arq);
                                                                  --Copiar aqui nome da tabela--
    forall v_indice in v_reg.first..v_reg.last insert into /*-->*/tabela_destino/*<--*/ values v_reg(v_indice);
    v_reg.delete;
    
    commit;
/*exception when OTHERS then
    raise_application_error(-20001,'Linha: '||v_num_linha||' '||v_campos(25));*/
end;

end;
/
