/*<info serverAlias="DBARC-bodb_Archive" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelByDayAll_Mem_Old]
	@CustId			INT
	, @FromDate		SMALLDATETIME
	, @TransType	INT				= 0
	, @Language		NVARCHAR(2)		= 'en'
	, @Error		INT				= 0		OUTPUT
	, @ErrorMsg		NVARCHAR(250)	= ''	OUTPUT
AS

/*
	Created: Jamie
	Date: 2010-03-18
	Task : Bet List for Daily Statement History
	DB: DBARC.bodb_Archive

	Revisions:
		- 20100611@Henry: For mix-parlay, match value is either 0 OR 9
		- 20100902@Kiwi: Add IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101224@Johnson: change column bettype from tinyint to smallint in temporary table
		- 20110620@Johnson: change column commission to playercomm
		- 20110725@Lukas: Get refund tickets
		- 20110825@Sophia: Edit betID not hard code bettype = 87, and show BetID for every bettype. If Deadball (liveindicator = 0), web code will hide BetID.
		- 20110826@Sophia: Add Bettype = 29, add column Actual_stake, show Betteam for System Parlay
		- 20110826@Jamie: Get modds as winning odds  for system parlay
		- 20110829@Sophia: Get BetID for Parlay
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
						- Add Sub table for Live Casino
		- 20120405@Hurri: Exclude bettype 72 in the calculation of Casino
						- Get more data of P2P (bettype: 1000)
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120927@Sophia: Get comstatus
		- 20121005@Viet: enhance SP, read data from bettrans_bk once only
		- 20130226@Lukas: move SP to bodb_archive
		- 20130225@Elodie: Add bet list of Virtual Horse Racing
		- 20130705@Kathy: Update matchid for RnG Casino (71) and Bingo (73)
		- 20130820@Kathy: Apply Progressive Bonus: bettype 72 for Casino
		- 20140306@Patrick: Add more Keno product
		- 20140310@Patrick: Exclude keno from Sportbook
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20160310@Kos: Don't support Deposit products
		- 20160323@Kos: Support Colossus Bet Grand Prize [Redmine: #54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20180201@Kos: Don't support Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]

	Param's Explanation:
		+ @TransType:
			0: All
			1: Betting Statement
			2: VOID/Cancelled Bet
			4: Grand Prize of ONERnG Jackpot
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM bodb02.dbo.All_f_TransStatus (1) stt
	WHERE 1 = CASE
				WHEN @TransType = 1 AND stt.StatusId IN (103, 111, 112, 113) THEN 1
				WHEN @TransType = 2 AND stt.StatusId IN (101, 102) THEN 1
				WHEN @TransType = 3 AND stt.StatusId IN (0, 1) THEN 1
				WHEN @TransType = 4 AND stt.StatusId IN (111, 112, 113) THEN 1
				ELSE 0
			END

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	IF @TransType <> 4
	BEGIN
		-- Don't support Deposit products (Playtech Casino, AG Casino, Microgaming Live Casino, Macau, Microgaming RNG Casino, BetTrade, CashOut, Exchange)
		-- Don't support Cockfighting, Horse Racing, Live Casino, Bingo, P2P, Bullfighting, Poker Games
		INSERT INTO @BettypeMatrix
		SELECT ProductID, BetType, EventType, SubProduct
		FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID NOT IN (2, 4, 7, 9, 10, 11, 13, 14, 15, 17, 19, 25, 26, 30, 31, 33)
			AND BetType NOT IN (901, 902, 903, 904)
	END
	ELSE		-- Grand Prize of ONERnG Jackpot
	BEGIN
		INSERT INTO @BettypeMatrix(ProductID, Bettype, EventType, SubProduct)
		SELECT ProductID, Bettype, EventType, SubProduct
		FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID = 6
	END

	-- CALL to core bet list
	EXEC [bodb_Archive].[dbo].[Age_CoreBetList_MemArc_SelBetTicket] 
		@CustID				= @CustID
		, @FromDate 		= @FromDate
		, @ToDate			= @FromDate
		, @TransStatus		= @TransStatus
		, @TransType		= @TransType
		, @BettypeMatrix	= @BettypeMatrix
		, @ColumnOutput		= 'sporttype,
								leagueid,
								homeid,
								awayid,
								bettype,
								matchcode,
								race,
								matchid,
								transid,
								transdate,
								winlostdate,
								refno,
								betid,
								oddsid,
								hdp1,
								hdp2,
								Modds,
								oddstype,
								odds,
								betteam,
								status,
								betstatus,
								stake,
								actual_stake,
								winlost,
								awinlost,
								mwinlost,
								swinlost,
								playercomm,
								comm,
								acomm,
								scomm,
								livehomescore,
								liveawayscore,
								liveindicator,
								finalhomescore,
								finalawayscore,
								hthomescore,
								htawayscore,
								ip,
								username,
								isNeutral,
								showtime,
								betcheck,
								comstatus,
								transdesc,
								OddsSpread'
	;

	RETURN;
END


GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem_Old] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem_Old] TO [bodbDownlineNetView]
GO
