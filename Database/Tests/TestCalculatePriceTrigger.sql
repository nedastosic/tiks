USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[ut_TestTriggerCalculatePrice]    Script Date: 5.9.2020. 12:59:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ut_TestTriggerCalculatePrice]
AS
 DECLARE @PackageID BIGINT;
 DECLARE @RegionID BIGINT;
 DECLARE @SkiPassID BIGINT;
 DECLARE @UserID BIGINT;
 DECLARE @ExpectedPrice FLOAT;
 DECLARE @ActualPrice FLOAT;
 DECLARE @MaxSlopeID BIGINT;
 SET NOCOUNT ON

 INSERT INTO Region (Name) values ('A');

 SET @RegionID = @@IDENTITY;  

 SET @MaxSlopeID = (SELECT MAX(SlopeID) FROM SkiSlope);

 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
 VALUES (@MaxSlopeID+1,@RegionID,'ss1',200,0.88,1);

 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
 VALUES (@MaxSlopeID+2,@RegionID,'ss2',200,0.4,1);

 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
 VALUES (@MaxSlopeID+3,@RegionID,'ss3',300,0.31,1);

 SET @PackageID = (SELECT MAX(PackageID) FROM Package) + 1;

 INSERT INTO Package (PackageID, Name) VALUES (@PackageID, 'P1');

 INSERT INTO PackageRegion (PackageID, RegionID, CreationDate) 
 VALUES (@PackageID,@RegionID,GETDATE());

 INSERT INTO SkiPass (Price, Status, PackageID)
 VALUES (0,1,@PackageID);

 SET @SkiPassID = @@IDENTITY; 

 INSERT INTO [dbo].[User](Firstname, Lastname, JMBG, DateOfBirth, Phone, Email  )
 VALUES ('FirstName', 'LastName', 'JMBG', GETDATE(), 'Phone', 'Email');

 SET @UserID = @@IDENTITY; 

 INSERT INTO Rental (RentalDate, SkiPassID, UserID, ValidFrom, ValidTo)
 VALUES (GETDATE(), @SkiPassID, @UserID, '2020-01-15', '2020-01-18');

 set @ExpectedPrice = 3*(0.88+0.4+0.31);

 set @ActualPrice = ( SELECT Price FROM SkiPass WHERE SkiPassID = @SkiPassID);

 IF (@ExpectedPrice != @ActualPrice)
    EXEC dbo.tsu_Failure 'TestTriggerCalculatePrice failed.' 
