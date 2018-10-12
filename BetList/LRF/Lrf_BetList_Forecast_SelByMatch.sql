/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

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
	DB: DB042.bodb02
	Original: [Lrf_BetList_Forecast_SelByMatch]
	Revisions:
		- 20131010@Victor: Add handicap parameter to show betlist of a specific handicap line
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150123@Jim: Support base on Currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170529@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180801@Kos: Migrate to DB042 [#Redmine: 99020]
		- 20181012@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]

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
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	SET @BetTeam = RTRIM(LTRIM(ISNULL(@BetTeam, '')))

	CREATE TABLE #Data (
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
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Discount			DECIMAL(9, 8),
		Ip					NVARCHAR(20),
		IsNeutral			BIT,
		OddsType			TINYINT,
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
		ShowTime			NVARCHAR(50),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT
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
		b.hdp1,
		b.hdp2,
		b.odds,
		CASE
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
		b.stake,
		b.actual_stake,
		b.transdate,
		b.betteam,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.discount,
		b.ip,
		ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.oddstype,
		b.betid,
		b.currency,
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
		END AS OriginalBetType,
		ISNULL(b.WalletType, 0) AS WalletType,
		ISNULL(b.RefCode, 0) AS RefCode
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.matchid = @MatchId
		AND ((@BetType = 0 AND b.bettype IN (1, 3, 7, 8))
			OR (@BetType <> 0 AND b.bettype = @BetType))
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
		DELETE FROM #Data
		WHERE hdp2 - hdp1 <> @handicap
	END

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake
		FROM #Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WalletType = 0
			FROM #Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(TransId) FROM #Data
	END

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.Status, b.TransId) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
				b.* ,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP,
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
