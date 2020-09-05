USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[ut_TestInsertSkiPass]    Script Date: 5.9.2020. 13:03:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ut_TestInsertSkiPass] AS

 EXEC [SkiPass.InsertSkiPass] 0,1,1

 IF @@ROWCOUNT = 0

  EXEC tsu_failure 'ut_TestInsertSkiPass failed'