USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[SkiPass.InsertSkiPass]    Script Date: 5.9.2020. 13:03:01 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SkiPass.InsertSkiPass]
       @Price						 FLOAT = 0, 
       @Status                  BIT = 1, 
       @PackageID					 BIGINT
AS 
BEGIN 
	 DECLARE @ErrorMessage VARCHAR(MAX) = '';
     SET NOCOUNT ON 

	 IF @Price < 0 
	 SET @ErrorMessage = @ErrorMessage + 'Price must be greater than 0.'


	 IF @ErrorMessage != ''
	 BEGIN
	 RAISERROR (@ErrorMessage,16,1)
	 RETURN
	 END


     INSERT INTO dbo.SkiPass
          (             
			Price,
			Status,
			PackageID
          ) 
     VALUES 
          ( 
			@Price,
			@Status,
			@PackageID
          ) 

END 