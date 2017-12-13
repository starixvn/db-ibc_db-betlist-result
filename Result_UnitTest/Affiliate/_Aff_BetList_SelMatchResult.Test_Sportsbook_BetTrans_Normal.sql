USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Aff_BetList_SelMatchResult].[Test_Sportsbook_BetTrans_Normal]    Script Date: 1/13/2017 12:52:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Aff_BetList_SelMatchResult].[Test_Sportsbook_BetTrans_Normal]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		SportType		INT,
		BetStatus		NVARCHAR(50),
		HtHomeScore		INT,
		HtAwaycore		INT,
		PlayTime		DATETIME,
		LeagueId		INT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		MatchCode		NVARCHAR(50),
		KickOffTime		DATETIME,
		EventDate		DATETIME,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		EventStatus		NVARCHAR(50),
		IsRefund		BIT,
		IsCalRefund		BIT,
		IsNeutral		BIT,
		GoalRecord		VARCHAR(50),
		IsHTCal			BIT,
		Calculate		BIT,
		IsPending		BIT,
		ShowTime		NVARCHAR(50),
		HomeId2			INT,
		AwayId2			INT
	)

	DECLARE @MatchId	INT,
		@BetType		SMALLINT = 1,
		@BetId			BIGINT,
		@RaceNo			VARCHAR(50)

	SELECT TOP 1
		@MatchId = m.matchid
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
	WHERE m.eventstatus NOT IN ('closed','running')
		AND m.sporttype BETWEEN 1 AND 99

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Aff_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR, @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR, @BetType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Count	INT,
			@Expected	INT

		SELECT @Count = COUNT(*)
		FROM bodb02.dbo.match AS m WITH(NOLOCK)
			LEFT OUTER JOIN bodb02.dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb02.dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @Expected = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals @Count, @Expected, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

GO
