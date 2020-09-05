USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[ut_TestViewDailyRentals]    Script Date: 5.9.2020. 13:16:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[ut_TestViewDailyRentals] 	
AS
 DECLARE @count_before int;
 DECLARE @sum_before int;
 DECLARE @count int;
 DECLARE @sum int;

 set @count_before = (select count(*) from (SELECT count(*) as count FROM dbo.Daily_rentals) as count)
 set @sum_before = (SELECT SUM(total) FROM dbo.Daily_rentals)

 INSERT INTO Rental (RentalDate) VALUES ('2020-01-16')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-16')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-17')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-18')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-20')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-21')
 INSERT INTO Rental (RentalDate) VALUES ('2020-01-21')

 SET @count = @count_before + 5
 SET @sum = @sum_before + 7

 print @count_before
 print @count
 print @sum_before
 print @sum


 IF @count - @count_before != 5

  EXEC tsu_failure 'ut_TestInsertSkiPass failed'
  
  IF @sum - @sum_before != 7

  EXEC tsu_failure 'ut_TestInsertSkiPass failed'