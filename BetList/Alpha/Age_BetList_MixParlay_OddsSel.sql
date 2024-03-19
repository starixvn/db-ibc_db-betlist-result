/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet, wsv_alp,bodbDownlineNetView, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_MixParlay_OddsSel]
	@TransIdList	VARCHAR(MAX)
AS

/*
	Created: 20231011@Kos
	Task: Alpha - Bet List - Get original odds for Mix Parlay tickets
	DB: DBAGE.bodb02

	Revisions:
		- 20231011@Kos: - 20231004@Kos: Support Parlay Boost [Redmine: #194992]

	Parameter's Explanation:
		- @TransIdList: list of Mix Parlay ticket transid seperated by commas (Ex: '21343535435353,41242334423,36464564654')
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		TransId		BIGINT,
		RefNo		BIGINT,
		Odds		MONEY,
		MOdds		MONEY,
		BoostRate	MONEY)

	INSERT INTO @Data
	SELECT
		b.transid,
		b.refno,
		0 AS Odds,
		0 AS MOdds,
		CASE
			WHEN b.bettype = 29 AND b.betteam = '1' AND b.oddsspread = 2 THEN
				ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
			ELSE 0
		END AS BoostRate
	FROM STRING_SPLIT(@TransIdList, ',') AS t
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = t.value

	DECLARE @TmpParlayData TABLE (
		RefNo	BIGINT,
		Odds	MONEY,
		MOdds	MONEY)

	-- Mix Parlay which having at least 1 settled sub ticket
	INSERT INTO @TmpParlayData
	SELECT
		b.RefNo,
		dbo.PRODUCT(bpd.odds) AS Odds,
		dbo.PRODUCT(bpd.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
	FROM @Data AS b
		INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
	GROUP BY
		b.RefNo,
		b.BoostRate

	-- Mix Parlay which having no settled sub ticket
	INSERT INTO @TmpParlayData
	SELECT
		b.RefNo,
		dbo.PRODUCT(bm.odds) AS Odds,
		dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
	FROM @Data AS b
		INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
	WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
	GROUP BY
		b.RefNo,
		b.BoostRate

	UPDATE b
	SET
		b.Odds = td.Odds,
		b.MOdds = td.MOdds
	FROM @Data AS b
		INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

	SELECT
		TransId,
		RefNo,
		Odds,
		MOdds
	FROM @Data
END
