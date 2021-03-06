USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[SkiPass.InsertUser]    Script Date: 07.09.2020. 21:37:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[SkiPass.InsertUser]
	@UserID BIGINT,
	@Firstname NVARCHAR(50),
	@Lastname NVARCHAR(50),
	@JMBG NVARCHAR(13),
	@DateOfBirth DATE,
	@Phone NVARCHAR(50),
	@Email NVARCHAR(50)
AS
BEGIN
SET NOCOUNT ON;
DECLARE @RetStat INT, @ErrorMessage NVARCHAR(500)
SET @RetStat = 0
	

    IF @JMBG IS NULL
	BEGIN
		SET @RetStat = 1
		SET @ErrorMessage = 'Polje JMBG je obavezno.'
	END

	IF @EMAIL NOT LIKE '_%@__%.__%'
	BEGIN 
		SET @RetStat = 2
		SET @ErrorMessage = 'Email nije u validom formatu.'
	END

	IF @RetStat <> 0
	BEGIN 
		RAISERROR (@ErrorMessage,16,@RetStat)
		RETURN
	END

IF @UserID = -2
	BEGIN
		INSERT INTO [dbo].[User]( Firstname, Lastname, JMBG, DateOfBirth, Phone, Email  )
		VALUES ( @Firstname, @Lastname, @JMBG, @DateOfBirth, @Phone, @Email)
		SET @UserID = SCOPE_IDENTITY()
	END
ELSE
	BEGIN
	UPDATE [dbo].[User]
	SET Firstname = @Firstname, Lastname = @Lastname, JMBG = @JMBG, DateOfBirth = @DateOfBirth, Phone = @Phone, Email = @Email
	WHERE UserID = @UserID
	END

	SET @RetStat = @@ERROR
	
	IF @RetStat <> 0
	BEGIN
		RAISERROR ('Greška prilikom inserta User-a.',16,@RetStat)
		RETURN
	END

	SELECT 0 AS Greska, 'Uspešno obavljen insert u tabelu dbo.User.' AS Poruka, @UserID AS ID
END
