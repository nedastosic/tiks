USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[SkiPass.InsertSkiPass]    Script Date: 03.09.2020. 22:42:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--ALTER PROCEDURE [dbo].[SkiPass.InsertSkiPass] 
 declare      @Price						 FLOAT = 0, 
       @Status                  BIT = 1, 
       @PackageID					 BIGINT
--AS

set @PackageID = 1;
set @Status = 1
BEGIN 
	 DECLARE	@ErrorMessage VARCHAR(MAX) = '',
				@SkiPassID BIGINT
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
	output INSERTED.SkiPassID
     VALUES 
          ( 
			@Price,
			@Status,
			@PackageID
          ) 
	SET @SkiPassID = SCOPE_IDENTITY()
	SELECT @SkiPassID AS ID
END 
