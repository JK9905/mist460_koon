-- ============================================================
-- Req 1, 3, 4: CheckAvailability - which rooms are free for a
-- given date/time range, optionally filtered by floor/seats/whiteboard
-- ============================================================
drop procedure if exists usp_CheckAvailability;
go
create procedure usp_CheckAvailability
    @AvailableDate date,
    @StartTime time,
    @EndTime time,
    @Floor int = null,
    @MinSeats int = null,
    @Whiteboard bit = null
as
begin
    set nocount on;

    declare @SlotsNeeded int = datediff(minute, @StartTime, @EndTime) / 15;

    select r.RoomID, r.RoomNumber, r.Floor, r.Seats, r.Whiteboard, r.CurrentStatus
    from Room r
    where (@Floor is null or r.Floor = @Floor)
        and (@MinSeats is null or r.Seats >= @MinSeats)
        and (@Whiteboard is null or r.Whiteboard = @Whiteboard)
        and r.RoomID in (
            select ra.RoomID
            from RoomAvailability ra
            where ra.AvailableDate = @AvailableDate
                and ra.StartTime >= @StartTime
                and ra.EndTime <= @EndTime
                and ra.AvailabilityStatus = 'Available'
            group by ra.RoomID
            having count(*) = @SlotsNeeded -- every 15-min slot in the range must be free
        );
end
go

-- ============================================================
-- Req 2: room capacity lookup
-- ============================================================
drop procedure if exists usp_GetRoomCapacity;
go
create procedure usp_GetRoomCapacity
    @RoomNumber varchar(10)
as
begin
    set nocount on;
    select RoomNumber, Seats
    from Room
    where RoomNumber = @RoomNumber;
end
go

-- ============================================================
-- Req 8: find a room available right now
-- ============================================================
drop procedure if exists usp_FindRoomAvailableNow;
go
create procedure usp_FindRoomAvailableNow
    @Floor int = null,
    @MinSeats int = null,
    @Whiteboard bit = null
as
begin
    set nocount on;

    declare @Today date = cast(getdate() as date);
    declare @NowTime time = cast(getdate() as time);
    -- round down to the current 15-minute slot boundary
    declare @SlotStart time = dateadd(minute, (datediff(minute, '00:00:00', @NowTime) / 15) * 15, '00:00:00');

    select r.RoomID, r.RoomNumber, r.Floor, r.Seats, r.Whiteboard, r.CurrentStatus
    from Room r
    where (@Floor is null or r.Floor = @Floor)
        and (@MinSeats is null or r.Seats >= @MinSeats)
        and (@Whiteboard is null or r.Whiteboard = @Whiteboard)
        and exists (
            select 1
            from RoomAvailability ra
            where ra.RoomID = r.RoomID
                and ra.AvailableDate = @Today
                and ra.StartTime = @SlotStart
                and ra.AvailabilityStatus = 'Available'
        );
end
go

-- ============================================================
-- Req 5, 6, 9: make a reservation
-- Validates: max 2-hour duration, 15-minute increments, slots are
-- free, and the user has no other reservation overlapping this time.
-- ============================================================
drop procedure if exists usp_MakeReservation;
go
create procedure usp_MakeReservation
    @AppUserID int,
    @RoomID int,
    @AvailableDate date,
    @StartTime time,
    @EndTime time,
    @ReservationID int output
as
begin
    set nocount on;
    set xact_abort on;

    declare @DurationMinutes int = datediff(minute, @StartTime, @EndTime);
    declare @SlotsNeeded int = @DurationMinutes / 15;

    if @DurationMinutes <= 0 or @DurationMinutes % 15 <> 0
    begin
        raiserror('Reservation time must be in 15-minute increments.', 16, 1);
        return;
    end

    if @DurationMinutes > 120
    begin
        raiserror('Reservation cannot exceed 2 hours.', 16, 1);
        return;
    end

    -- Req 6: block a second reservation for a different room at an overlapping time
    if exists (
        select 1
        from Reservation res
        join RoomAvailability ra on ra.ReservationID = res.ReservationID
        where res.AppUserID = @AppUserID
            and res.ReservationStatus in ('Reserved', 'CheckedIn')
            and ra.RoomID <> @RoomID
            and ra.AvailableDate = @AvailableDate
            and ra.StartTime < @EndTime
            and ra.EndTime > @StartTime
    )
    begin
        raiserror('You already have a reservation for a different room at an overlapping time.', 16, 1);
        return;
    end

    begin transaction;

    if (
        select count(*)
        from RoomAvailability
        where RoomID = @RoomID
            and AvailableDate = @AvailableDate
            and StartTime >= @StartTime
            and EndTime <= @EndTime
            and AvailabilityStatus = 'Available'
    ) <> @SlotsNeeded
    begin
        rollback transaction;
        raiserror('Room is not available for the full requested time range.', 16, 1);
        return;
    end

    insert into Reservation (AppUserID, ReservationDateTime, ReservationStatus)
    values (@AppUserID, getdate(), 'Reserved');

    set @ReservationID = scope_identity();

    -- Req 11: mark the covered slots reserved immediately
    update RoomAvailability
    set AvailabilityStatus = 'Reserved', ReservationID = @ReservationID
    where RoomID = @RoomID
        and AvailableDate = @AvailableDate
        and StartTime >= @StartTime
        and EndTime <= @EndTime;

    commit transaction;
end
go

-- ============================================================
-- Req 10, 11: cancel a reservation and free its slots immediately
-- ============================================================
drop procedure if exists usp_CancelReservation;
go
create procedure usp_CancelReservation
    @ReservationID int
as
begin
    set nocount on;
    set xact_abort on;

    begin transaction;

    update RoomAvailability
    set AvailabilityStatus = 'Available', ReservationID = null
    where ReservationID = @ReservationID;

    update Reservation
    set ReservationStatus = 'Cancelled'
    where ReservationID = @ReservationID;

    commit transaction;
end
go

-- ============================================================
-- Req 7: check-in / check-out
-- ============================================================
drop procedure if exists usp_CheckIn;
go
create procedure usp_CheckIn
    @ReservationID int
as
begin
    set nocount on;

    update Reservation
    set CheckInDateTime = getdate(), ReservationStatus = 'CheckedIn'
    where ReservationID = @ReservationID;

    update Room
    set CurrentStatus = 'In Use'
    where RoomID in (
        select RoomID from RoomAvailability where ReservationID = @ReservationID
    );
end
go

drop procedure if exists usp_CheckOut;
go
create procedure usp_CheckOut
    @ReservationID int
as
begin
    set nocount on;
    set xact_abort on;

    begin transaction;

    declare @RoomID int = (select top 1 RoomID from RoomAvailability where ReservationID = @ReservationID);

    update Reservation
    set CheckOutDateTime = getdate(), ReservationStatus = 'CheckedOut'
    where ReservationID = @ReservationID;

    -- Req 11: release the room immediately once checked out
    update RoomAvailability
    set AvailabilityStatus = 'Available', ReservationID = null
    where ReservationID = @ReservationID;

    update Room
    set CurrentStatus = 'Available'
    where RoomID = @RoomID;

    commit transaction;
end
go

select *
from Room
where Whiteboard = 1;

select * from RoomAvailability;