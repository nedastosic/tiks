CREATE PROCEDURE [SkiPassTests].[test trg_calculate_price] 
AS 
BEGIN 

	DECLARE @ExpectedPrice float;
	DECLARE @ActualPrice float;
    
	EXEC tSQLt.FakeTable 'dbo.Region';
	EXEC tSQLt.FakeTable 'dbo.PackageRegion';
	EXEC tSQLt.FakeTable 'dbo.SkiSlope';
	EXEC tSQLt.FakeTable 'dbo.Package';
	EXEC tSQLt.FakeTable 'dbo.SkiPass';
	EXEC tSQLt.FakeTable 'dbo.User';

	INSERT INTO Region (RegionID, Name) values (1, 'A');

	 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
	 VALUES (1,1,'ss1',200,1,1);
	 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
	 VALUES (2,1,'ss1',500,2,1);
	 INSERT INTO SkiSlope (SlopeID, RegionID, Name, Capacity, Price, SlopeTypeID)
	 VALUES (3,1,'ss1',1000,5,1);

	 INSERT INTO Package (PackageID, Name) VALUES (1, 'P1');

	 INSERT INTO PackageRegion (PackageID, RegionID, CreationDate) 
     VALUES (1,1,GETDATE());

 	 INSERT INTO SkiPass (SkiPassID, Price, Status, PackageID)
	 VALUES (1,0,1,1);

	 INSERT INTO [dbo].[User](UserID, Firstname, Lastname, JMBG, DateOfBirth, Phone, Email  )
	 VALUES (1, 'FirstName', 'LastName', 'JMBG', GETDATE(), 'Phone', 'Email');

	 INSERT INTO Rental (RentalDate, SkiPassID, UserID, ValidFrom, ValidTo)
	 VALUES (GETDATE(), 1, 1, '2020-01-15', '2020-01-18');

	 set @ExpectedPrice = 3*(1+2+5);

	 set @ActualPrice = ( SELECT Price FROM SkiPass WHERE SkiPassID = 1);

	 EXEC tSQLt.assertEquals @ExpectedPrice, @ActualPrice;
	 
END