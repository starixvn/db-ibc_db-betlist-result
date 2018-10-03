/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_BetList_SelByDayAll_Mem]
	@CustId			INT
	, @FromDate		SMALLDATETIME
	, @MoveBetsDay	SMALLDATETIME
	, @TransType	INT				= 0
	, @Language		NVARCHAR(2)		= 'EN'
	, @Error 		INT				= 0		OUTPUT
	, @ErrorMsg		NVARCHAR(250)	= ''	OUTPUT
AS

/*
	Created:
	Task: Bet List for Daily Statement
	DB: DBAGE.bodb02
	Original:Acc_BetListByDayAll_1
	Revisions:
		- 20081030@QuangVinh: Add more result for Horseracing,TransType: 0: all bets, 1: bets settled, 2: void and cancelled, 3: running and waiting
		- 20090326@Phuc: get indexname for FI
		- 20090407@Amy: Get refno for Mix parlay
						- Remove INNER JOIN bettype table for Mix parlay
		- 20090414@Amy: get more field betid for Casino
		- 20090416@Minh: remove indexName
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@Henry: Change formula of commission
		- 20090528@Henry: get more result for Horse racing fix odds;Get more data from bettransm, bettransm14 for HR
		- 20090618@AnhPham: Remove 'Customer' table
		- 20090630@AnhPham: Remove 'creator' field from table variable and insert statement
		- 20090710@Phuc: unhide IP for TB currency.
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status
		- 20091024@MinhNguyen: get modds, finalodds
		- 20100318@Jamie: Remove input param @transid and enhance checking the group of bet tickets
		- 20100610@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110113@Jamie: Put index hint on bettransm & bettransm14 
		- 20110114@Thien: Put index hint on bettrans/bettrans14
		- 20110408@Amy: Change function to get Odds value and showed odds type
		- 20110512@Johnson: Apply new arrange bettype
		- 20110620@Johnson: change column commission to playercomm
		- 20110725@Lukas: Get refund tickets when transtype = 1
		- 20110825@Sophia: Edit betID not hard code bettype = 87, and show BetID for every bettype. If Deadball (liveindicator = 0), web code will hide BetID
		- 20110826@Sophia: Add Bettype = 29, add column Actual_stake, show Betteam for System Parlay
		- 20110826@Jamie: Get modds as winning odds for system parlay
		- 20110829@Sophia: Get BetID for Parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120112@Sophia: Add showtime for Table - Shoe - Hand of LiveCasino
						- Add Sub table for Live Casino
		- 20120405@Hurri: Exclude bettype 72 and 23101 in the calculation of Casino
						- Get more data of P2P (bettype: 1000, 23102)
		- 20120309@Sophia: Not to use Checktime and SecAcceptFlag showing waiting or running status for Casino, Bingo, P2P, Outright, Mix parlay
		- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
		- 20120426@Lukas: show transid of mainticket for all sub-tickets of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120927@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual Horse Racing
		- 20130401@Lukas: fix bugs - wrong selected table
		- 20130705@Kathy: Update matchid for RnG Casino (71) and Bingo (73)
		- 20130820@Kathy: Apply Progressive Bonus: bettype 72 for Casino
		- 20140303@Elodie: Add Keno sport [Redmine:#12756]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
		- 20150326@Cody: Remove RnG Casino Casino (71) and Bingo (73) for OutStanding value [Redmine: #15274]
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150909@Kos: Fix bug not show CB ticket after clicking Grand Prize in Statement report
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20160310@Kos: Don't support Deposit products
		- 20160519@Francis: Change to use inline function to enhance performance
		- 20170620@Kos: Add param @MoveBetsDay [#Redmine: 77280]
		- 20180201@Kos: Don't support Racing, Live Casino, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]

	Param's Explanation:
		+ @TransType:
			1: Betting Statement
			2: VOID/Cancelled Bet
			3: Outstanding Bet 
			4: Grand Prize of Colossus Bet
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @TransStatus	[dbo].[TVP_BetTicketStatus]
		, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]

	-- Gather Ticket status
	INSERT INTO @TransStatus
	SELECT StatusId
	FROM dbo.All_f_TransStatus (1) stt
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
		-- Don't support Deposit products (Playtech Casino, AG Casino, Microgaming Live Casino, Macau, Microgaming RNG Casino, BetTrade, Cash Out)
		-- Don't support Racing, Live Casino, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting, Exchange
		INSERT INTO @BettypeMatrix(ProductID, Bettype, EventType, SubProduct)
		SELECT ProductID, Bettype, EventType, SubProduct
		FROM f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID NOT IN (2, 4, 7, 9, 10, 11, 13, 14, 17, 19, 25, 31)
			AND BetType NOT IN (901, 902, 903, 904, 71, 72)
	END
	ELSE		-- Grand Prize of ONERnG Jackpot, Colossus Bet
	BEGIN
		INSERT INTO @BettypeMatrix(ProductID, Bettype, EventType, SubProduct)
		SELECT ProductID, Bettype, EventType, SubProduct
		FROM f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID IN (6, 15)
	END

	-- CALL to core bet list
	EXEC [dbo].[Age_CoreBetList_Mem_SelBetTicket]
		@CustId				= @CustId
		, @FromDate			= @FromDate
		, @ToDate			= @FromDate
		, @MoveBetsDay		= @MoveBetsDay
		, @TransType		= @TransType
		, @Language			= @Language
		, @TransStatus		= @TransStatus
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
END


GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbAdminNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_SelByDayAll_Mem] TO [vnteam] AS [dbo]
GO
