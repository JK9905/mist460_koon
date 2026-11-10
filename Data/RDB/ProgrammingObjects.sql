if OBJECT_ID('dbo.procRecordEvent', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procRecordEvent;

if OBJECT_ID('dbo.trgUpdateRoomStatus', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trgUpdateRoomStatus;

if OBJECT_ID('dbo.procUpdateRoomStatus', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procUpdateRoomStatus;

if OBJECT_ID('dbo.procReleaseExpiredHolds', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procReleaseExpiredHolds;

if OBJECT_ID('dbo.procStartReservation', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procStartReservation;

if OBJECT_ID('dbo.procHoldSlot', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procHoldSlot;

if OBJECT_ID('dbo.procConfirmReservation', 'P') IS NOT NULL
    DROP PROCEDURE dbo.procConfirmReservation;

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

go

create or alter procedure procReleaseExpiredHolds
as
begin
    -- free slots whose pending reservation is older than 10 minutes
    update ra
    set AvailabilityStatus = 'Available', ReservationID = null
    from RoomAvailability ra inner join Reservation r
    on ra.ReservationID = r.ReservationID
    where r.ReservationStatus = 'Pending'
      and r.ReservationDateTime < dateadd(minute, -10, getdate());

    -- then cancel those abandoned reservations (must run after the slot update above)
    update Reservation
    set ReservationStatus = 'Cancelled'
    where ReservationStatus = 'Pending'
      and ReservationDateTime < dateadd(minute, -10, getdate());

end;

go

create or alter procedure procStartReservation
    @AppUserID int
as
begin
    -- create a pending reservation when the student starts picking slots
    insert into Reservation (AppUserID, ReservationStatus)
    values (@AppUserID, 'Pending');

    select SCOPE_IDENTITY() as ReservationID;  -- pass this to procHoldSlot

end;

go

create or alter procedure procHoldSlot
    @RoomAvailabilityID int,
    @ReservationID int
as
begin
    exec procReleaseExpiredHolds;

    -- only succeeds if the slot is still open, the reservation is still pending,
    -- and the reservation has fewer than 8 slots (8 x 15 min = 2 hour max)
    update RoomAvailability
    set AvailabilityStatus = 'Pending', ReservationID = @ReservationID
    where RoomAvailabilityID = @RoomAvailabilityID
      and AvailabilityStatus = 'Available'
      and exists (select 1 from Reservation where ReservationID = @ReservationID and ReservationStatus = 'Pending')
      and (select count(*) from RoomAvailability where ReservationID = @ReservationID) < 8;

    select @@ROWCOUNT as SlotHeld;  -- 1 = got it, 0 = taken, expired, or at the 2 hour max

end;

go

create or alter procedure procConfirmReservation
    @ReservationID int
as
begin
    exec procReleaseExpiredHolds;  -- an expired hold can't be confirmed

    update RoomAvailability
    set AvailabilityStatus = 'Reserved'
    where ReservationID = @ReservationID
      and AvailabilityStatus = 'Pending';

    update Reservation
    set ReservationStatus = 'Reserved',
        TotalTimeReserved = (select count(*) * 15 from RoomAvailability where ReservationID = @ReservationID)
    where ReservationID = @ReservationID
      and ReservationStatus = 'Pending';

    select @@ROWCOUNT as Confirmed;  -- 1 = confirmed, 0 = expired or not pending

end;
