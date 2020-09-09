
-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Description:	Insert user
-- =============================================
ALTER PROCEDURE [dbo].[SQLTest_InsertUser]
	
AS
BEGIN
DECLARE @UserID BIGINT
CREATE TABLE #ExpectedResult(ID BIGINT  NOT NULL PRIMARY KEY IDENTITY,
							Firstname NVARCHAR(50), 
							Lastname NVARCHAR(50), 
							JMBG NVARCHAR(13), 
							DateOfBirth DATETIME, 
							Phone NVARCHAR(50), 
							Email NVARCHAR(50))

CREATE TABLE #ActualResult(	ID BIGINT  NOT NULL PRIMARY KEY IDENTITY,
							Firstname NVARCHAR(50), 
							Lastname NVARCHAR(50), 
							JMBG NVARCHAR(13), 
							DateOfBirth DATETIME, 
							Phone NVARCHAR(50), 
							Email NVARCHAR(50))

INSERT INTO #ExpectedResult(Firstname,Lastname,JMBG,DateOfBirth,Phone,Email)
		VALUES('testIme', 'testPrezime', '1111111111111', '2020-02-02', '+381656011065', 'test@gmail.com')
		
EXEC dbo.[SkiPass.InsertUserReturnID]	@UserID OUTPUT, 
										@Firstname = 'testIme', 
										@Lastname = 'testPrezime', 
										@JMBG = '1111111111111', 
										@DateOfBirth = '2020-02-02', 
										@Phone = '+381656011065',
										@Email = 'test@gmail.com'
										
INSERT INTO #ActualResult
	SELECT Firstname,Lastname,JMBG,DateOfBirth,Phone,Email
	FROM dbo.[User]
	WHERE UserID = @UserID

EXEC TST.Assert.TableEquals 'Provera inserta user-a.'

DROP TABLE #ActualResult
DROP TABLE #ExpectedResult

END
GO
