USE bodb_archive
GO
ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelMainInfoArc]
(
	@tempCust		TVP_TicketSportBettype READONLY,
	@ColumnOutput	VARCHAR(MAX)	= NULL
)
AS

/*
	Created: Bobby.Nguyen
	Task: Re-factor core bet list
	DB: DBARC.bodb_archive
	Original:

	Revisions:
		- 20150504@Bobby: Create new SP - Apply GD product
		- 20150526@Bobby: Apply metric-gaming bettype
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160907@Kos: Extend length of transdesc to 1000 to support NG2
		- 20170508@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20180126@Kos: Support ONERnG Jackpot [#Redmine: 88652]

	Param's Explanation:

	Dependences:
		- CREATE TABLE @tempCust
		( 
			transid			BIGINT
			, refno			BIGINT
			, custid 		INT
			, productId 	INT
			, eventType		TINYINT
			, WhTicket		TINYINT
		)
*/

BEGIN
	SET NOCOUNT ON;

	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, TransDate			DATETIME
		, WinLostDate		DATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				NVARCHAR(15)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		SMALLMONEY
		, BetdaqId			BIGINT
	);

	-- CHECK for selecting from bettrans_bk
	IF EXISTS (SELECT TOP(1) 1 FROM @tempCust WHERE WhTicket IN (3, 8))
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettransArc] @tempCust = @tempCust
	END

	-- OUTPUT main ticket
	/*IF (@ColumnOutput IS NULL)
	BEGIN
		SELECT *
		FROM #MemBetTicket t
		ORDER BY t.transid DESC
	END
	ELSE
	BEGIN 
		DECLARE @queryOutput NVARCHAR(MAX)
		SET @queryOutput = 'SELECT' 
							+ ' ' + @ColumnOutput 
							+ ' FROM #MemBetTicket t'
							+ '	ORDER BY t.transid DESC '
		
		EXEC sp_sqlexec @queryOutput
	END
	*/

	SELECT
		t.*,
		e.currency
	FROM #MemBetTicket AS t
		LEFT JOIN bodb02.dbo.custInfo AS c WITH (NOLOCK) ON t.CustId = c.custid
		LEFT JOIN bodb02.dbo.Exchange AS e WITH (NOLOCK) ON c.currency = e.exchangeid
	ORDER BY t.TransId DESC

	-- OUTPUT ticket in detail
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelDetailArc] @tempCust = @tempCust

	RETURN;
END

GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNetView]
GO
