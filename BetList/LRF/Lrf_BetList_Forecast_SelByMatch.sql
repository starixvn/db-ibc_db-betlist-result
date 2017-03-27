set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER PROCEDURE [dbo].[Lrf_BetList_Forecast_SelByMatch]
	@AgentList		VARCHAR(MAX),
	@MatchId		INT,
	@BetType		INT			= 0,
	@BetTeam		VARCHAR(20)	= NULL,
	@LiveIndicator	INT			= -1,
	@Handicap		SMALLMONEY	= NULL,
	@PageSize		INT			= 1000,
	@PageIndex		INT			= 1,
	@BetChoice		VARCHAR(10)	= 'All',
	@TotalRows		INT			= 0		OUTPUT
AS

/*
	Created: Victor@20130802
	Task: Forecast
	DB: DBEXT.bodb02
	Original: [Lrf_BetList_Forecast_SelByMatch]
	Revisions:
		- 20131010@Victor: Add handicap parameter to show betlist of a specific handicap line
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150123@Jim: Support base on Currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]

	Param's explanation:
		- BetChoice: one of the following list: 'All','Home', 'Away', 'Over', 'Under'
			+ Full: List all tickets bet on FT Handicap or FT Over/Under (@bettype must be 0)
			+ Half: List all tickets bet on HT Handicap or HT Over/Under (@bettype must be 0)
			+ Home: List all Tickets bet on Home team
			+ Away: List all tickets bet on Away team
			+ Over: List all tickets bet on 'Over' 
			+ Under: List all tickets bet on 'Under'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	SET @BetTeam = RTRIM(LTRIM(ISNULL(@BetTeam, '')))

	CREATE TABLE #Data (
		CustId			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		Race			VARCHAR(50),
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		TransDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Discount		DECIMAL(9,8),
		Ip				NVARCHAR(20),
		IsNeutral		BIT,
		OddsType		TINYINT,
		BetId			BIGINT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		PlayerComm		MONEY,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT
	)

	INSERT INTO #Data
	SELECT
		b.custid,
		m.sporttype,
		b.Username,
		b.bettype,
		b.transid,
		m.matchcode,
		'' AS Race,
		m.leagueid,
		m.homeid,
		m.awayid,
		CONVERT(FLOAT, b.hdp1) AS hdp1,
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		CASE
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		b.stake,
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.discount,
		b.ip,
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.oddstype,
		b.betid,
		b.winlostdate,
		b.currency,
		b.playercomm,
		b.refno,
		ISNULL(m.showtime,'') AS showtime,
		ISNULL(b.betdaqid, -1) AS BetdaqId,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		CASE
			WHEN b.ExtraInfo LIKE '%p25%' THEN
				ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
			ELSE 0
		END AS OriginalStake,
		CASE
			WHEN b.stake <> 0 THEN -1
			ELSE 0
		END AS OriginalBetType
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid 
	WHERE b.matchid = @MatchId
		AND ((@BetType = 0 AND b.bettype IN (1, 3, 7, 8))
			OR (@BetType != 0 AND b.bettype = @BetType))
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.statusID IN (0, 1)
		AND ((@LiveIndicator = -1)
			OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
			OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
		AND ((@BetTeam = '')
			OR (@BetTeam <> '' AND b.betteam = @BetTeam))
	ORDER BY
		b.status,
		b.transid

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	-- Filter data by BetChoice
	IF @BetChoice LIKE 'Home'
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'h'
	END
	ELSE IF @BetChoice LIKE 'Away'
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'a'
	END
	ELSE IF @BetChoice LIKE 'Over'
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'h'
	END
	ELSE IF @BetChoice LIKE 'Under'
	BEGIN
		DELETE FROM #Data WHERE betteam NOT LIKE 'a'
	END
	ELSE IF @BetChoice LIKE 'Full'
	BEGIN
		DELETE FROM #Data WHERE bettype IN (7, 8)
	END
	ELSE IF @BetChoice LIKE 'Half'
	BEGIN
		DELETE FROM #Data WHERE bettype IN (1, 3)
	END
	ELSE
	BEGIN
		DELETE FROM #Data
	END

	-- Filter data by Handicap
	IF @BetChoice IN ('Home','Away') AND @handicap IS NOT NULL
	BEGIN
		DELETE FROM #Data WHERE hdp2-hdp1 != @handicap
	END

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(TransId) FROM #Data
	END

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.Status, b.TransId) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				b.* ,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.PlayerComm * e.USD AS PlayerCommUSD,
				b.PlayerComm * e.EUR AS PlayerCommEUR,
				b.PlayerComm * e.GBP AS PlayerCommGBP,
				b.OriginalStake * e.USD AS OriginalStakeUSD,
				b.OriginalStake * e.EUR AS OriginalStakeEUR,
				b.OriginalStake * e.GBP AS OriginalStakeGBP
			FROM #Data AS b
				INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.Currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Data
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Forecast_SelByMatch] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Forecast_SelByMatch] TO vnteam
GO

