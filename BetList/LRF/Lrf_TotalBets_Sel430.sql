USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_TotalBets_Sel430]
	@LicenseeId		INT,
	@CurrencyId		INT				= 0,
	@UserId			INT,
	@LicenseeType	VARCHAR(100)	= NULL,
	@LangKey		VARCHAR(10)		= 'en-US',
	@PageSize		INT				= 50,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Created: Henry@20101209
	Task : Betlist for Correct score and first correct score
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20140620@Florent: offer new bettypes 152 - Half Time/Full Time Correct Score
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150124@Winnie: Add base currency GBP 
		- 20150420@Jim: add more bettype 165, 166
		- 20151203@Bobby: Database - Change datatype [Redmine: #48660]
		- 20151207@Kos: Include bet type 405 2H Correct Score [Redmine: #47959]
		- 20160129@Kos: Include bet type 413 Correct Score (aos) and [414] 1H Correct Score (aos) [Redmine: #50897]
		- 20170720@Kos: Include bet type 416 Half Time/Full Time Correct Score (own) [Redmine: #53153]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		CustId			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		RefNo			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Discount		DECIMAL(9,8),
		LeagueId		INT,
		Ip				NVARCHAR(30),
		IsNeutral		BIT,
		OddsType		TINYINT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		TransDesc		NVARCHAR(200)
	)

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc
		INNER JOIN #currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	INSERT INTO @Data
	SELECT
		b.custid,
		m.sporttype,
		b.username,
		b.bettype,
		b.transid,
		b.refno,
		m.matchcode,
		m.homeid,
		m.awayid,
		CONVERT(FLOAT, b.hdp1) AS hdp1,
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		b.modds,
		b.status,
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
		ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
		b.oddstype,
		b.winlostdate,
		b.currency,
		ISNULL(b.transdesc, '') AS transdesc
	FROM
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE
		b.Recommend IN (SELECT custid FROM @TempAg)
		AND((@CurrencyID = 0 AND currency IN (SELECT currencyId FROM #currency))
			OR (@CurrencyID <> 0 AND Currency = @CurrencyID))
		AND b.bettype IN (4, 30, 152, 165, 166, 405, 413, 414, 416)
		AND b.statusID IN (0, 1)
		AND b.tpositiontaking <> 0 
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

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(transid) FROM @Data
	END

	SELECT A.*
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.status, b.transid) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS nickname,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP
			FROM @Data AS b
				INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) AS e ON e.exchangeid = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #currency
END


GO
GRANT EXECUTE ON [dbo].[Lrf_TotalBets_Sel430] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_TotalBets_Sel430] TO vnteam
 