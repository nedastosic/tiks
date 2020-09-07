ALTER PROCEDURE [SkiPassTests].[test insert ski pass - price must be greater than 0] 
AS 
BEGIN 
     SET NOCOUNT ON 

	 EXEC tSQLt.FakeTable 'dbo.SkiPass';

	 EXEC tSQLt.ExpectException @ExpectedMessagePattern  = '%Price must be greater than 0.%';

	 EXEC dbo.[SkiPass.InsertSkiPass] @Price = -1,  @PackageID = null;
	 
END