USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelMatchResult].[Test_HorseRacing_BetTrans]    Script Date: 12/1/2017 10:52:24 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelMatchResult].[Test_HorseRacing_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		HorseNo		VARCHAR(50),
		KickOffTime	DATETIME,
		RaceName	VARCHAR(50),
		Place		TINYINT,
		SportType	INT,
		HorseId		INT,
		Odds		SMALLMONEY,
		PlaceOdds	SMALLMONEY,
		MeetingId	INT,
		OddsStatus	VARCHAR(10),
		IsFavor		VARCHAR(10),
		IsSCR		BIT,
		FOddsStatus	VARCHAR(10),
		TF			VARCHAR(10),
		SCR			VARCHAR(10),
		[RowCount]	INT
	)

	DECLARE @MatchId	INT,
		@BetType		SMALLINT = 31,
		@BetId			BIGINT,
		@RaceNo			VARCHAR(50),
		@LeagueId		INT,
		@EventDate		DATETIME

	SELECT TOP 1
		@MatchId = o.orid,
		@RaceNo = o.groupmatch,
		@LeagueId = o.leagueid,
		@EventDate = o.eventdate
	FROM bodb02.dbo.outright AS o WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
	WHERE o.oddsstatus = 'completed'
		AND o.groupmatch IS NOT NULL
		AND (ISNULL(o.Placing, 0) <> 0 OR o.IsSCR = 1)

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@RaceNo = ''' + @RaceNo + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Expected = COUNT(*)
		FROM bodb02.dbo.outright AS o WITH (NOLOCK)
			INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
		WHERE o.leagueid = @LeagueId
			AND o.groupmatch = @RaceNo
			AND o.eventdate = @EventDate
			AND ISNULL(o.placing, 0) <> 0

		SELECT @Actual = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = @Expected,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO
