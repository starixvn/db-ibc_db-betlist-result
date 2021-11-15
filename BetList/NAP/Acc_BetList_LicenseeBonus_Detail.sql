/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_LicenseeBonus_Detail]
	@TransId	BIGINT,
	@RefCode	BIGINT,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: Kos@20170515
	Task: Get ticket detail of Licensee Bonus System ticket [#Redmine: 74978]
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180927@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190506@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191127@Kos: Hotfix - Change oddsspread data type from SMALLMONEY to MONEY [Redmine: #124483]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211115@Razor: Enhance to get Detail ticket [Redmine: #164614]
		
	Parameters:
		- @TransId: TransId of summary ticket of multiple of Bonus/Cash sub tickets
		- @RefCode: RefCode of summary ticket
			- @TransId = @RefCode: summary ticket is from single Bonus sub ticket only
			- @TransId <> @RefCode: summary ticket is from multiple Bonus/Cash sub ticket
*/

BEGIN
	SET NOCOUNT ON

	-- Create temp table
	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(50),
		EventDate			SMALLDATETIME,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			SMALLINT,
		Ip					VARCHAR(45),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ExtraInfo			VARCHAR(1000)
	)

	DECLARE @CustId		INT,
		@WinLostDate	SMALLDATETIME,
		@WhTicket		TINYINT

	SELECT @CustId = b.custid,
		@WinLostDate = b.winlostdate,
		@WhTicket = 1
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.transid = @TransId
		AND (b.RefCode = @RefCode OR @TransId = @RefCode)
		AND b.winlostdate > @MoveBetsDay

	IF @WinLostDate IS NULL
	BEGIN
		SELECT @CustId = b.custid,
			@WinLostDate = b.winlostdate,
			@WhTicket = 2
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.transid = @TransId
			AND (b.RefCode = @RefCode OR @TransId = @RefCode)
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

		IF @WinLostDate IS NULL
		BEGIN
			SELECT @CustId = b.custid,
				@WinLostDate = b.winlostdate,
				@WhTicket = 3
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
				AND (b.RefCode = @RefCode OR @TransId = @RefCode)
		END
	END

	-- Get ticket
	IF @WhTicket = 1	-- Bettrans range
	BEGIN
		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.liveindicator,
			b.modds,
			b.custid,
			b.livehomescore,
			b.liveawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			(b.scomm - b.acomm) AS SComm,
			(b.acomm - b.comm) AS AComm,
			(b.comm - b.playercomm) AS Comm,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
	END
	ELSE IF @WhTicket = 2	-- Bettrans14 range
	BEGIN
		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			0 AS SettlementStatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.liveindicator,
			b.modds,
			b.custid,
			b.livehomescore,
			b.liveawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			b.ip,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			(b.scomm - b.acomm) AS SComm,
			(b.acomm - b.comm) AS AComm,
			(b.comm - b.playercomm) AS Comm,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
	END
	ELSE IF @WhTicket = 3	-- Bettrans_bk range
	BEGIN
		INSERT INTO @Data
		SELECT
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0) AS BetId,
			b.refno,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			b.sdiscount,
			b.adiscount,
			b.discount,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.oddstype,
			b.status,
			0 AS SettlementStatus,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.liveindicator,
			b.modds,
			b.custid,
			b.livehomescore,
			b.liveawayscore,
			m.finalhomescore,
			m.finalawayscore,
			m.leagueid,
			m.sporttype,
			dp.ip,
			b.matchid,
			ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS Commission,
			(b.scomm - b.acomm) AS SComm,
			(b.acomm - b.comm) AS AComm,
			(b.comm - b.playercomm) AS Comm,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			m.showtime,
			b.winlostdate,
			b.betcheck,
			ISNULL(b.transdesc, '') AS TransDesc,
			ISNULL(b.oddsspread, 0) AS OddsSpread,
			ISNULL(b.WalletType, 0) AS WalletType,
			0 AS RefCode,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.custid = @CustId
			AND b.winlostdate = @WinLostDate
			AND ((@TransId = @RefCode AND b.transid = @TransId)
				OR (@TransId <> @RefCode AND b.RefCode = @RefCode))
	END

	SELECT * FROM @Data
	ORDER BY TransId
END
GO


GRANT	EXECUTE	ON	[Acc_BetList_LicenseeBonus_Detail]	TO	bodbAdminNet
GO
