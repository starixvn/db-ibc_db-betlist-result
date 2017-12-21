USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelRunningByBettypeMatch].[Test_OverUnder]    Script Date: 1/11/2017 5:35:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelRunningByBettypeMatch].[Test_OverUnder]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum				INT,
		Nickname			NVARCHAR(50),
		CustId				INT,
		SportType			INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		TransId				BIGINT,
		MatchCode			VARCHAR(50),
		Race				VARCHAR(50),
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Status				NVARCHAR(50),
		Stake				MONEY,
		TransDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Discount			DECIMAL(9,8),
		Ip					NVARCHAR(20),
		IsNeutral			BIT,
		OddsType			TINYINT,
		BetId				BIGINT,
		WinLostDate			DATETIME,
		Currency			SMALLINT,
		PlayerComm			MONEY,
		RefNo				BIGINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		StakeUSD			MONEY,
		StakeEUR			MONEY,
		StakeGBP			MONEY,
		PlayerCommUSD		MONEY,
		PlayerCommEUR		MONEY,
		PlayerCommGBP		MONEY,
		OriginalStakeUSD	MONEY,
		OriginalStakeEUR	MONEY,
		OriginalStakeGBP	MONEY
	)

	DECLARE @LicenseeId	INT		= 26,	-- Athena000
		@UserId			INT		= 68,
		@TransId		BIGINT,
		@MatchId		INT,
		@BetType		INT		= 3		-- Over/Under

	DECLARE @Temp TABLE (Currency INT, CurrencyName VARCHAR(100), IsActive BIT, AgentId INT)

	INSERT INTO @Temp
	EXEC bodb02.dbo.Lrf_SelCurrencyByLicenseeUser
		@LicenseeID = @LicenseeId,
		@UserID = @UserId

	DECLARE @AgentList VARCHAR(MAX)

	SELECT @AgentList = (
		SELECT AgentId, Currency FROM @Temp
		WHERE IsActive = 1
		FOR XML RAW('Agent'), ROOT('ROOT')
	)

	SELECT TOP(1)
		@TransId = b.transid,
		@MatchId = b.matchid
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		INNER JOIN bodb02.dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
	WHERE b.bettype = @BetType
		AND b.currency IN (SELECT DISTINCT Currency FROM @Temp)
		AND b.recommend IN (SELECT DISTINCT AgentId FROM @Temp)
		AND b.statusID = 0

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelRunningByBettypeMatch] 
							@MatchID = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@AgentList = ''' + CONVERT(VARCHAR(MAX), @AgentList) + ''',
							@Bettype = ' + CONVERT(VARCHAR(5), @BetType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

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
