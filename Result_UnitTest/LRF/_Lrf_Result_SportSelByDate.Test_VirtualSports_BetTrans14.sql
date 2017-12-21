USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_Result_SportSelByDate].[Test_VirtualSports_BetTrans14]    Script Date: 1/13/2017 2:14:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_Result_SportSelByDate].[Test_VirtualSports_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType	SMALLINT,
		SportName	NVARCHAR(50)
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay
	FROM @tmp

	DECLARE @EventDate	DATETIME,
		@SportType		SMALLINT

	SELECT TOP(1)
		@EventDate = o.eventdate,
		@SportType = r.sporttype
	FROM bodb02.dbo.VSRaceInfo AS r WITH(NOLOCK)
		INNER JOIN bodb02.dbo.VSOutright14 AS o WITH(NOLOCK) ON o.EventID = r.EventID
	WHERE r.eventstatus = 'completed'
		AND r.sporttype IN (181, 183, 185)

	IF @SportType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_Result_SportSelByDate]
							@EventDate = ''' + CONVERT(VARCHAR(10), @EventDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''',
							@LicenseeId = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual	INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE SportType = @SportType

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = 1,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
