USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelMatchResult].[Test_VirtualSports_BetTrans14]    Script Date: 12/1/2017 10:36:52 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelMatchResult].[Test_VirtualSports_BetTrans14]
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
		@RaceNo			VARCHAR(50)

	SELECT TOP(1)
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

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@RaceNo = ''' + @RaceNo + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Expected = COUNT(*)
		FROM bodb02.dbo.VSOutright14 AS o WITH (NOLOCK)
			INNER JOIN bodb02.dbo.VSRaceInfo AS r WITH (NOLOCK) ON o.EventID = r.EventID
		WHERE o.EventID = @MatchId
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
