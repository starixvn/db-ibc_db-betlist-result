USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_Result_SportSelByDate].[Test_Sportsbook_BetTrans]    Script Date: 1/13/2017 2:10:50 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_Result_SportSelByDate].[Test_Sportsbook_BetTrans]
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

	DECLARE @MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay, 
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	DECLARE @EventDate	DATETIME,
		@SportType		SMALLINT

	SELECT TOP(1)
		@EventDate = m.eventdate,
		@SportType = m.sporttype
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH(NOLOCK) ON m.sporttype = s.SportType
	WHERE s.ProductID = 1
		AND m.sporttype NOT IN (201, 162)
		AND m.eventstatus NOT IN ('closed', 'running')

	IF @SportType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_Result_SportSelByDate]
							@EventDate = ''' + CONVERT(VARCHAR, @EventDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@LicenseeId = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

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
