if OBJECT_ID('dbo.procRecordEvent', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procRecordEvent;

if OBJECT_ID('dbo.trgUpdateRoomStatus', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trgUpdateRoomStatus;

if OBJECT_ID('dbo.procUpdateRoomStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procUpdateRoomStatus;

go
create or alter procedure procRecordEvent
    @MacAddress nvarchar(17),
    @EventType nvarchar(5)
as
begin

    declare @SensorID int;

    select @SensorID = SensorID from Sensor where MacAddress = @MacAddress;

    insert into SensorLog (SensorID, EventType, EventDateTime)
    values (@SensorID, @EventType, SYSDATETIMEOFFSET() AT TIME ZONE 'Eastern Standard Time');

end;



go 

create or alter trigger trgUpdateRoomStatus
on SensorLog
after insert
as
begin
    declare @EventType nvarchar(5), @RoomID int

    select @EventType = i.EventType, @RoomID = s.RoomID
    from inserted i inner join Sensor s 
    on i.SensorID = s.SensorID;

    if (@EventType = 'Enter')
        update Room
        set CurrentStatus = 'Occupied'
        where RoomID = @RoomID;
    
    else if (@EventType = 'Exit')
        update Room
        set CurrentStatus = 'Available'
        where RoomID = @RoomID;
        
end;

go

create or alter procedure procUpdateRoomStatus
    @RoomID int,
    @RoomStatus nvarchar(20)

as
begin
    update Room
    set CurrentStatus = @RoomStatus
    where RoomID = @RoomID;

end;
