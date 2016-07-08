USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_CoreBetList_BetTicket_SelMainInfo]
(
	@tempCust		[dbo].[TVP_TicketSportBettype]	READONLY
	, @TransStatus	[dbo].[TVP_BetTicketStatus]		READONLY
	, @ColumnOutput	VARCHAR(MAX)	= NULL
)
AS

/*
	Created: Bobby.Nguyen
	Task : Re-factor core bet list
	DB: DBAGE.bodb02
	Original: 

	Revisions:
		- 20150504@Bobby.Nguyen: Create new SP - Apply GD product
		- 20150526@Bobby.Nguyen: Apply metric-gaming bettype
		- 20150827@Kos.Nguyen: Add column OddsSpread to support Myanmar Odds
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160111@Kos: Add @TransStatus to support RNG Casino Single Wallet [Redmine: #48958]
		- 20162017@Kos: Add WhTicket = 5 to support AllBet [Redmine: #50864]

	Param's Explanation:
		- @tempCust  AS TABLE
		( 
			transid			BIGINT
			, refno			BIGINT
			, custid		INT
			, productId		INT
			, eventType		TINYINT
			, WhTicket		TINYINT
		)
*/

BEGIN
	SET NOCOUNT ON;
	
	-- CREATE output main info ticket
	CREATE TABLE #MemBetTicket
	(
		TransId				BIGINT
		, RefNo				BIGINT
		, custid			INT
		, Username			NVARCHAR(30)
		, Sporttype			SMALLINT
		, Bettype 			SMALLINT
		, BetId				BIGINT
		, Betteam			NVARCHAR(20)
		, hdp1				SMALLMONEY
		, hdp2				SMALLMONEY
		, OddsType			TINYINT
		, oddsid			INT
		, Odds				MONEY 
		, modds				MONEY
		, Stake				MONEY
		, actual_stake		MONEY
		, Status			NVARCHAR(10)
		, transdate			DATETIME
		, winlostdate		DATETIME
		, winlost			MONEY
		, awinlost			MONEY
		, mwinlost			MONEY
		, swinlost			MONEY
		, playerComm		MONEY
		, comm				MONEY
		, acomm				MONEY
		, scomm				MONEY
		, apositiontaking	SMALLMONEY
		, mpositiontaking	SMALLMONEY
		, spositiontaking	SMALLMONEY
		, tpositiontaking	SMALLMONEY
		, adiscount			SMALLMONEY
		, mdiscount			SMALLMONEY
		, sdiscount			SMALLMONEY
		, liveindicator		BIT
		, livehomescore		SMALLINT
		, liveawayscore		SMALLINT
		, finalhomescore	SMALLINT
		, finalawayscore	SMALLINT
		, hthomescore		SMALLINT
		, htawayscore		SMALLINT
		, IP				NVARCHAR(15)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, eventdate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, Betstatus			NVARCHAR(50)
		, isNeutral			BIT
		, Placing			NVARCHAR(20)
		, showtime			NVARCHAR(50)
		, betcheck			NVARCHAR(50)
		, comstatus			NVARCHAR(20)
		, transdesc			NVARCHAR(300)
		, OddsSpread		SMALLMONEY
	);

	-- CHECK for selecting from translog
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 0)
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelTranslog] @tempCust = @tempCust, @TransStatus = @TransStatus
	END

	-- CHECK for selecting from bettrans, bettransRnG, bettransLC
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket IN (1, 4, 5))
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettrans] @tempCust = @tempCust, @TransStatus = @TransStatus
	END

	-- CHECK for selecting from bettrans14
	IF EXISTS (SELECT TOP 1 1 FROM @tempCust WHERE WhTicket = 2)
	BEGIN
		INSERT INTO #MemBetTicket
		EXEC [dbo].[Age_CoreBetList_BetTicket_SelBettrans14] @tempCust = @tempCust, @TransStatus = @TransStatus
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

	SELECT *
	FROM #MemBetTicket t
	ORDER BY t.transid DESC

	-- OUTPUT ticket in detail
	EXEC [dbo].[Age_CoreBetList_BetTicket_SelDetail] @tempCust = @tempCust

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_CoreBetList_BetTicket_SelMainInfo] TO [bodbDownlineNetView]
GO
