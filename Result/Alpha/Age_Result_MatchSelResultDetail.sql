/*<info serverAlias="DBAGE-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Result_MatchSelResultDetail]
	@MatchId INT
AS

/*
	Created: 20141016@Sophia
	Task: Alpha Result Report - Get match result detail
	DB: DBAGE.bodb02
	Revisions:
		- 20141218@Sophia: Not to use Betstatus to get REFUND status of Tennis anymore
		- 20150324@Sophia: Support to get BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20161021@Kos: Exclude Fast Market result [#Redmine: 56589]
		- 20170117@Kos: Support new result status Abandoned 1H/2H [#Redmine: 70410]
		- 20170405@Kos: Support Basketball AIO [#Redmine: 73033]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20171012@Kos: Support PH AIO Phase 3 [Redmine: #82403]
		- 20180320@Kos: Exclude Fast Market 2 [Redmine: #90708]
		- 20180410@Kos: Support Betradar Virtual Basketball [Redmine: #90616]
		- 20181003@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
					- Move eventstatus data transform to web (no change for Tennis)
		- 20181122@Kos: Support E-Sports phase 2 [Redmine: #101047]
		- 20190805@Kos: Support PH AIO 4b [Redmine: #115235]
					- Change for "Next Goal" [Redmine: #115235]
		- 20191014@Kos: Support Badminton AIO phase 2 [Redmine: #120381]
		- 20191204@Kos: Show Instant Calculation Result for Corner Bettypes [Redmine: #124682]
		- 20200515@Kos: Support PH AIO phase 5.1 [Redmine: #132770]
		- 20201006@Razor: Support Time Machine Over/Under [Redmine: #141998]
		- 20210223@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210414@Razor: Support Time Machine HDP [Redmine: #152749]
		- 20210823@Razor: Support Cricket AIO 1.2 [Redmine: #160409]
		- 20220310@Razor: Support Cricket AIO 2 [Redmine: #166334]
		- 20220622@Razor: Support More map for eSports [Redmine: #174251]
		- 20220711@Razor: Support Volleyball AIO [Redmine: #173861]
		- 20230316@Razor: Change HT Score display for Soccer [Redmine: #181331]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportType SMALLINT

	DECLARE @Detail TABLE (
		MatchId				INT,
		ResourceId			VARCHAR(20),
		HomeValue			VARCHAR(50),
		AwayValue			VARCHAR(50),
		ResultStatusId		TINYINT,
		SettlementStatusId	TINYINT,
		OtherInfo			VARCHAR(2000)
	)

	IF EXISTS (SELECT 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchId)
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.GlobalShowTime AS kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			m.showtime,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore
		FROM dbo.match AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.MatchId = @MatchId

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND ((@SportType = 1
						AND SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType IN (6, 9, 50)		-- Volleyball, Badminton, Cricket
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9)
							OR (@SportType = 50 AND ResourceID IN ('9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchID,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd WITH (NOLOCK)
			WHERE MatchID = @MatchId AND SettlementStatusID > 0
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
	END
	ELSE
	BEGIN
		SELECT
			m.sporttype,
			m.betstatus,
			m.leagueid,
			m.matchid,
			m.matchcode,
			m.eventdate,
			m.GlobalShowTime AS kickofftime,
			m.homeid,
			m.awayid,
			m.hthomescore,
			m.htawayscore,
			m.finalhomescore,
			m.finalawayscore,
			CASE m.sporttype
				WHEN 5 THEN
					CASE ISNULL(r.SettlementStatusID, 0)
						WHEN 1 THEN 'Refund'
						WHEN 2 THEN 'Refund HT'
						WHEN 3 THEN 'Refund FT'
						ELSE m.eventstatus
					END
				ELSE m.eventstatus
			END AS EventStatus,
			m.showtime,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.GoalRecord,
			ISNULL(m.homeid2, 0) AS homeid2,
			ISNULL(mr.IsHTCal, 0) AS IsHTCal,
			ISNULL(mr.calculate, 0) AS calculate,
			0 AS SettlementStatus,
			ISNULL(mr.NoHTScore, 0) AS NoHTScore
		FROM dbo.match14 AS m WITH (NOLOCK)
			LEFT JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN dbo.ResultDetail14 AS r WITH (NOLOCK) ON r.MatchID = m.matchid AND r.ResourceId = '00'
		WHERE m.matchid = @MatchId

		-- Get sport type
		SELECT @SportType = sporttype
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId

		-- Get result detail
		IF @SportType IN (1, 2, 5)
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND ((@SportType = 1
						AND SettlementStatusID > 0
						AND (ResourceID NOT IN ('08', '09')
							OR HomeValue LIKE '%a%'
							OR HomeValue LIKE '%h%')
						AND ResourceID NOT IN ('00', '01', '04', '05', '14F', '14L', '127F', '127L', '135', '168', '173', '174', '175', '176', 
							'192', '193', '206', '207', '208', '209', '210', '211', '212', '213', '214', '215', '488', '489', '490', '376')
						AND ResourceID NOT LIKE '160%'
						AND ResourceID NOT LIKE '164%'
						AND ResourceID NOT LIKE '169%'
						AND ResourceID NOT LIKE '180%'
						AND ResourceID NOT LIKE '216%'
						AND ResourceID NOT LIKE '217%'
						AND ResourceID NOT LIKE '221%'
						AND ResourceID NOT LIKE '222%'
						AND ResourceID NOT LIKE '223%'
						AND ResourceID NOT LIKE '224%'
						AND ResourceID NOT LIKE '225%'
						AND ResourceID NOT LIKE '226%'
						AND ResourceID NOT LIKE '227%'
						AND ResourceID NOT LIKE '228%'
						AND ResourceID NOT LIKE '229%'
						AND ResourceID NOT LIKE '486%'
						AND ResourceID NOT LIKE '487%')
					OR (@SportType = 5
						AND SettlementStatusID > 0)
					OR (@SportType = 2
						AND (LEN(ResourceID) = 2
							OR SettlementStatusID > 0)))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType IN (6, 9, 50)		-- Volleyball, Badminton, Cricket
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailOS14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) = 2
					OR (LEN(ResourceID) = 4 AND @SportType IN (6, 9))
					OR (SettlementStatusID > 0
						AND (@SportType IN (6, 9)
							OR (@SportType = 50 AND ResourceID IN ('9400', '9401', '9442', '9443', '9446', '9447', '9450', '9449', '9452', '9453', '94511', '96151')))))
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 43		-- E-Sports
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchId,
				ResourceId,
				HomeValue,
				AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetailES14 WITH (NOLOCK)
			WHERE MatchID = @MatchId
				AND (LEN(ResourceID) IN (2, 3) OR SettlementStatusID > 0)
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
		ELSE IF @SportType = 193
		BEGIN
			INSERT INTO @Detail
			SELECT
				MatchID,
				ResourceId,
				Custom1 AS HomeValue,
				Custom2 AS AwayValue,
				ResultStatusID,
				SettlementStatusID,
				OtherInfo
			FROM dbo.ResultDetail3rd14 WITH (NOLOCK)
			WHERE MatchID = @MatchId AND SettlementStatusID > 0
			ORDER BY MatchID ASC,
				ResourceId ASC
		END
	END

	SELECT * FROM @Detail
END
GO
