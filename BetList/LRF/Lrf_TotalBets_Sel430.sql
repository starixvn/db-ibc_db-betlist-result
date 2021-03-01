/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel430]
	@AgentList		VARCHAR(MAX),
	@BaseCurrency	VARCHAR(10),
	@PageSize		INT			= 50,
	@PageIndex		INT			= 1,
	@TotalRows		INT			= 0 OUTPUT
AS

/*
	Created: Henry@20101209
	Task: Betlist for Correct score and first correct score
	DB: DBBOF.bodb02
	Original:
	Revisions:
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140620@Florent: offer new bettypes 152 - Half Time/Full Time Correct Score
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150124@Winnie: Add base currency GBP
		- 20150420@Jim: add more bettype 165, 166
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		- 20151207@Kos: Include bet type 405 2H Correct Score [Redmine: #47959]
		- 20160129@Kos: Include bet type 413 Correct Score (aos) and [414] 1H Correct Score (aos) [Redmine: #50897]
		- 20160720@Kos: Include bet type 416 Half Time/Full Time Correct Score (own) [Redmine: #53153]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170529@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180801@Kos: Migrate to DB042 [#Redmine: 99020]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190520@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20190715@Kos: Hotfix - Show KickOffTime Incorrectly [#Redmine: 116777]
		- 20190729@Kos: Support new status Pending [#Redmine: 117729]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
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

	DECLARE @Data TABLE (
		CustId				INT,
		SportType			INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		TransId				BIGINT,
		RefNo				BIGINT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Modds				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		INT,
		Discount			DECIMAL(9,8),
		LeagueId			INT,
		Ip					NVARCHAR(30),
		IsNeutral			BIT,
		OddsType			TINYINT,
		Currency			SMALLINT,
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT
	)

	INSERT INTO @Data
	SELECT
		b.custid,
		m.sporttype,
		b.username,
		b.bettype,
		b.transid,
		b.refno,
		m.matchcode,
		m.GlobalShowTime AS EventDate,
		m.homeid,
		m.awayid,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		CASE
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
		b.stake,
		b.actual_stake,
		b.transdate,
		b.betteam,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.discount,
		m.leagueid,
		b.ip,
		ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
		b.oddstype,
		b.currency,
		ISNULL(b.transdesc, '') AS transdesc,
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
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND b.bettype IN (4, 30, 152, 165, 166, 405, 413, 414, 416)
		AND b.statusID IN (0, 1)
		AND b.tpositiontaking <> 0

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
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
		FROM @Data
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
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Get total rows
	SELECT @TotalRows = COUNT(transid) FROM @Data

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @TotalRows > 0
	BEGIN
		INSERT INTO #ExchangeRate
		SELECT
			e.ExchangeId,
			CASE
				WHEN @BaseCurrency = 'MYR' THEN e.MYR
				WHEN @BaseCurrency = 'USD' THEN e.USD
				WHEN @BaseCurrency = 'EUR' THEN e.EUR
				WHEN @BaseCurrency = 'CNY' THEN e.CNY
				WHEN @BaseCurrency = 'IDR' THEN e.IDR
				WHEN @BaseCurrency = 'GBP' THEN e.GBP
				WHEN @BaseCurrency = 'THB' THEN e.THB
				WHEN @BaseCurrency = 'INH' THEN e.INH
				WHEN @BaseCurrency = 'BDT' THEN e.BDT
				WHEN @BaseCurrency = 'INR' THEN e.INR
				ELSE 1
			END AS Rate
		FROM dbo.Lrf_f_GetExchangeDaily(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)) AS e
		WHERE EXISTS (SELECT 1 FROM @Data WHERE Currency = e.ExchangeId)
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	SELECT A.*
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.Status ASC, b.TransId ASC) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.CustId,
				b.SportType,
				b.Username,
				b.BetType,
				b.TransId,
				b.RefNo,
				b.MatchCode,
				b.EventDate,
				b.HomeId,
				b.AwayId,
				b.Hdp1,
				b.Hdp2,
				b.Odds,
				b.Modds,
				b.Status,
				b.SettlementStatus,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.TransDate,
				b.BetTeam,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.LiveIndicator,
				b.Discount,
				b.LeagueId,
				b.Ip,
				b.IsNeutral,
				b.OddsType,
				b.Currency,
				b.TransDesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
				b.OriginalBetType,
				b.WalletType,
				b.RefCode
			FROM @Data AS b
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.CustId
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd
END
GO
