USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_Result_SportSelByDate].[Test_HorseRacing_BetTrans]    Script Date: 1/13/2017 2:03:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_Result_SportSelByDate].[Test_HorseRacing_BetTrans]
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
		@SportType = l.sporttype
	FROM bodb02.dbo.league AS l WITH (NOLOCK)
		INNER JOIN bodb02.dbo.outright AS o WITH(NOLOCK) ON o.leagueid = l.leagueid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH(NOLOCK) ON l.sporttype = s.SportType
	WHERE s.ProductID = 2
		AND o.oddsstatus = 'completed'

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
