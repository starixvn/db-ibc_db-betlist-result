USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_Result_SportSelByDate].[Test_VirtualSports_BetTrans14]    Script Date: 1/13/2017 1:39:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_Result_SportSelByDate].[Test_VirtualSports_BetTrans14]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		SportType	TINYINT,
		SportName	NVARCHAR(50)
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay, 
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	DECLARE @EventDate	DATETIME,
		@SportType		TINYINT

	SELECT TOP 1
		@EventDate = o.eventdate,
		@SportType = r.sporttype
	FROM bodb02.dbo.VSRaceInfo AS r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.VSOutright14 AS o WITH(NOLOCK) ON o.EventID = r.EventID
	WHERE r.eventstatus = 'completed'
		AND r.sporttype IN (181, 182, 183, 184, 185)

	IF @SportType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_Result_SportSelByDate]
							@EventDate = ''' + CONVERT(VARCHAR, @EventDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@IsShowAll = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Expected	INT

		SELECT @Expected = COUNT(*)
		FROM @Data
		WHERE SportType = @SportType

		-- Assert
		EXEC tSQLt.AssertEquals 1, @Expected, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

GO
