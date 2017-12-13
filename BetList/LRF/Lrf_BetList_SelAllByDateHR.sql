ALTER PROCEDURE [dbo].[Lrf_BetList_SelAllByDateHR]
	@AgentList			VARCHAR(MAX),
	@BetType			INT,
	@MatchId			INT,
	@PageSize			INT		= 1000,
	@PageIndex			INT		= 1,
	@TotalRows			INT		= 0 OUTPUT,
	@SumWinLost			MONEY	= 0 OUTPUT,
	@SumLicenseeWL		MONEY	= 0 OUTPUT,
	@SumComm			MONEY	= 0 OUTPUT,
	@SumPlayerComm		MONEY	= 0 OUTPUT,
	@SumWinLostUSD		MONEY	= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY	= 0 OUTPUT,
	@SumCommUSD			MONEY	= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY	= 0 OUTPUT,
	@SumWinLostEUR		MONEY	= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY	= 0 OUTPUT,
	@SumCommEUR			MONEY	= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY	= 0 OUTPUT,
	@SumWinLostGBP		MONEY	= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY	= 0 OUTPUT,
	@SumCommGBP			MONEY	= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY	= 0 OUTPUT
AS

/*
	Created: Henry@20101208
	Task: get Horse Racing tickets for Agent level
	DB: DBEXTbodb02
	Original 
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110308@Henry: get more sporttype (152,153)
		- 20110712@Henry: output column LicenseeWL insteed of AWinlost
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120724@Jim: add player commision value
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150127@Winnie: Add base currency GBP 
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]
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

	DECLARE @FromDate DATETIME,
		@ToDate DATETIME

	SELECT @ToDate = CONVERT(DATETIME, CONVERT(NVARCHAR(20), GETDATE(), 101))
	SELECT @FromDate = DATEADD(dd, -1, @ToDate)
 
	DECLARE @Data TABLE (
		Username		NVARCHAR(50),
		NickName		NVARCHAR(50),
		SportType		INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		MatchId			INT,
		Race			VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		MOdds			MONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			VARCHAR(50),
		LeagueId		INT,
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(20),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		Currency		SMALLINT
	)

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	INSERT INTO @Data
	SELECT
		b.Username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
		l.sporttype,
		b.bettype,
		b.transid,
		m.matchcode,
		b.matchid,
		m.groupmatch AS Race,
		m.teamid AS homeID,
		0 AS awayID,
		b.hdp1,
		b.hdp2,
		modds,
		b.odds,
		b.status,
		b.stake,
		(winlost - actual_stake) AS winlost,
		b.awinlost,
		b.comm,
		b.playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		'' AS Betteam,
		m.leagueid,
		0 AS liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.ip,
		'' AS betstatus,
		CONVERT(BIT,0) AS IsNeutral,
		b.currency
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
	WHERE
		b.matchid = @MatchId
		AND b.bettype = @BetType
		AND b.recommend IN (SELECT CustId FROM @TempAg)
		AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
		AND m.eventdate BETWEEN @FromDate AND @ToDate
	ORDER BY b.transid DESC

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @Fdate DATETIME
	DECLARE @Tdate DATETIME 

	SELECT @Fdate = MIN(winlostdate),
		@Tdate = MAX(winlostdate)
	FROM @Data

	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL	= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm		= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm	= SUM(ISNULL(b.PlayerComm, 0)),
		-- USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		-- EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM @Data AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FDate,@TDate)) AS e
			ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency

	SELECT c.*
	FROM
		(
			SELECT 
				ROW_NUMBER() OVER(ORDER BY b.transid DESC) AS RowNum,
				b.*,
				-- USD
				b.Stake			* e.USD AS StakeUSD,
				b.WinLost		* e.USD AS WinLostUSD,
				b.LicenseeWL	* e.USD AS LicenseeWLUSD,
				b.Comm			* e.USD AS CommUSD,
				b.PlayerComm	* e.USD AS PlayerCommUSD,
				-- EUR
				b.Stake			* e.EUR AS StakeEUR,
				b.WinLost		* e.EUR AS WinLostEUR,
				b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
				b.Comm			* e.EUR AS CommEUR,
				b.PlayerComm	* e.EUR AS PlayerCommEUR,
				-- GBP
				b.Stake			* e.GBP AS StakeGBP,
				b.WinLost		* e.GBP AS WinLostGBP,
				b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
				b.Comm			* e.GBP AS CommGBP,
				b.PlayerComm	* e.GBP AS PlayerCommGBP
			FROM @Data AS b
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)) e
					ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency
		) c
	WHERE c.RowNum BETWEEN @RowStart AND @RowEnd

	IF @Bettype = 33 OR @Bettype = 43
	BEGIN
		SELECT
			bm.refno,
			bm.finalodds,
			bm.odds,
			bm.status,
			bm.apositiontaking,
			0 AS mpositiontaking,
			0 AS spositiontaking,
			bm.bettype
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN @Data AS b ON bm.refno = b.transid
		WHERE b.BetType = @BetType
	END
END

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelAllByDateHR] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelAllByDateHR] TO [vnteam]
GO
