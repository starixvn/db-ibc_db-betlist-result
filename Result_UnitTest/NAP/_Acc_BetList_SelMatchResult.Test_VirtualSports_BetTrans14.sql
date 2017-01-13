USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_SelMatchResult].[Test_VirtualSports_BetTrans14]    Script Date: 1/13/2017 11:23:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_SelMatchResult].[Test_VirtualSports_BetTrans14]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		MatchCode	VARCHAR(10),
		Placing		TINYINT,
		SportType	INT,
		Runner		INT,
		LeagueId	INT,
		EventTime	NVARCHAR(50),
		HorseNo		NVARCHAR(50),
		WinOdds		NVARCHAR(50),
		PlaceOdds	NVARCHAR(50),
		IsFavor		NVARCHAR(50)
	)

	DECLARE @MatchId	INT,
		@BetType		SMALLINT = 31,
		@BetId			BIGINT,
		@RaceNo			VARCHAR(50),
		@LeagueId		INT,
		@EventDate		DATETIME

	SELECT TOP 1
		@MatchId = o.EventID,
		@RaceNo = o.Orid
	FROM bodb02.dbo.VSOutright14 AS o WITH (NOLOCK)
		INNER JOIN bodb02.dbo.VSRaceInfo AS r WITH(NOLOCK) ON o.EventID = r.EventID
	WHERE r.EventStatus = 'completed'
		AND o.Orid IS NOT NULL

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR, @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR, @BetType) + ',
							@RaceNo = ''' + @RaceNo + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Count	INT,
			@Expected	INT

		SELECT @Count = COUNT(*)
		FROM bodb02.dbo.VSOutright14 AS o WITH (NOLOCK)
			INNER JOIN bodb02.dbo.VSRaceInfo AS r WITH(NOLOCK) ON o.EventID = r.EventID
		WHERE o.EventID = @MatchId
			AND ISNULL(o.placing, 0) <> 0

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
