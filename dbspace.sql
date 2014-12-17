use master
go
create table #daily_db_usage_size
(
      name          varchar(30)     not null,
      id            int             not null,
      db_size       numeric(10,2)   null,
      data_size     numeric(10,2)   null,
      data_used     numeric(10,2)   null,
      data_free     numeric(10,2)   null,
      data_pct      numeric(10,2)   null,
      log_size      numeric(10,2)   null,
      log_used      numeric(10,2)   null,
      log_free      numeric(10,2)   null,
      log_pct       numeric(10,2)   null,
      REC_UPD_DT    datetime        not null
)
go
create index daily_db_usage_sizeI2 on #daily_db_usage_size(REC_UPD_DT)
go
    declare name_crsr cursor  for
        select dbid, rtrim(name) from master..sysdatabases noholdlock
go
declare @scale float
declare @name varchar(30)
declare @id int

declare @dbsize float

declare @datasize float
declare @data_free float
declare @data_used float
declare @data_pct float

declare @logsize float
declare @log_free float
declare @log_used float
declare @log_pct float

select  @scale=d.low
from    master..spt_values d
where   d.number = 1 and d.type = "E"

open name_crsr
fetch name_crsr into @id, @name
while (@@sqlstatus = 0)
begin

    select @datasize = sum(size)*@scale/1048576
        from master..sysusages a noholdlock
        where dbid = @id and segmap !=4

    select @data_free = sum(curunreservedpgs(@id, u.lstart, u.unreservedpgs))*@scale/1048576
        from master..sysusages u where dbid = @id and segmap !=4

    /* Just log */
    select @logsize = sum(size)*@scale/1048576
        from master..sysusages u
                where u.dbid = @id
                /* and   u.segmap & 3 = 0 */
                and   u.segmap = 4

    if @logsize is null or @logsize = 0
        select @log_free=0,@log_used=0,@logsize=0, @log_pct = 0
    else
        begin
            select @log_free = lct_admin("logsegment_freepages", @id) *@scale/1048576
            select @log_used = @logsize - @log_free
            if @log_used = 0
                select @log_pct = 0
            else
                select @log_pct = (@log_used*100)/@logsize
        end

    select @data_used = @datasize - @data_free
    select @data_pct = (@data_used*100)/@datasize
    select @dbsize = @datasize+@logsize
    
    insert into #daily_db_usage_size
        values
           (@name,
            @id,
            convert(numeric(10,2),@dbsize),
            convert(numeric(10,2),@datasize),
            convert(numeric(10,2),@data_used),
            convert(numeric(10,2),@data_free),
            convert(numeric(10,2),@data_pct),
            convert(numeric(10,2),@logsize),
            convert(numeric(10,2),@log_used),
            convert(numeric(10,2),@log_free),
            convert(numeric(10,2),@log_pct),
            getdate()
           )

    fetch name_crsr into @id, @name
end
close name_crsr
deallocate cursor name_crsr
go
select * from #daily_db_usage_size
go
drop table #daily_db_usage_size
go
