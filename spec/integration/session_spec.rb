# frozen_string_literal: true

RSpec.describe 'SessionSpec' do
  it 'knows session is closed' do
    session = driver.session
    session.close
    expect(session).not_to be_open
  end

  it 'handles nil config' do
    driver = Neo4j::Driver::GraphDatabase.driver(uri, Neo4j::Driver::AuthTokens.basic('neo4j', 'password'), nil)
    session = driver.session
    session.close
    expect(session).not_to be_open
    driver.close
  end

  it 'handles nil AuthToken' do
    expect { Neo4j::Driver::GraphDatabase.driver(uri, nil) {} }
      .to raise_error Neo4j::Driver::Exceptions::AuthenticationException
  end

  it 'executes read transaction in read session' do
    test_read_transaction(Neo4j::Driver::AccessMode::READ)
  end

  it 'executes read transaction in write session' do
    test_read_transaction(Neo4j::Driver::AccessMode::WRITE)
  end

  it 'executes write transaction in read session' do
    test_write_transaction(Neo4j::Driver::AccessMode::READ)
  end

  it 'executes write transaction in write session' do
    test_write_transaction(Neo4j::Driver::AccessMode::WRITE)
  end

  it 'rolls back write transaction in read session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::READ)
  end

  it 'rolls back write transaction in write session when function throws exception' do
    test_tx_rollback_when_function_throws_exception(Neo4j::Driver::AccessMode::WRITE)
  end

  # it 'retries read transaction until success' do

  # end

  # it 'retries write transaction until success' do

  # end

  # it 'retries read transaction until failure' do

  # end

  # it 'retries write transaction until failure' do

  # end

  # it 'collects write transaction retry errors' do

  # end

  # it 'collects read transaction retry errors' do

  # end

  it 'commits read transaction without success' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.read_transaction { |tx| tx.run('RETURN 43').single[0] }
    expect(answer).to eq(43)
    expect(session.last_bookmark).not_to be nil
  end

  it 'commits write transaction without success' do
    session = driver.session
    answer = session.write_transaction { |tx| tx.run("CREATE (:Person {name: 'Thor Odinson'}) RETURN 42").single[0] }
    expect(answer).to eq(42)
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Thor Odinson'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(1)
  end

  it 'rolls back read transaction with failure' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.read_transaction do |tx|
      val = tx.run('RETURN 42').single[0]
      tx.failure
      val
    end
    expect(answer).to eq(42)
    expect(session.last_bookmark).to be nil
  end

  it 'rolls back write transaction with failure' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.write_transaction do |tx|
      val = tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
      tx.failure
      42
    end
    expect(answer).to eq(42)
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end


  it 'rolls back read transaction when exception is thrown' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    expect { 
      session.read_transaction do |tx|
        val = tx.run('RETURN 42').single[0]
        raise Neo4j::Driver::Exceptions::IllegalStateException if val == 42
        1
      end
    }.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    expect(session.last_bookmark).to be nil
  end
 
  it 'rolls back write transaction when exception is thrown' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    expect {
      session.write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
        raise Neo4j::Driver::Exceptions::IllegalStateException
      end
    }.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  it 'rolls back read transaction when marked both success and failure' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.read_transaction do |tx|
      val = tx.run('RETURN 42').single[0]
      tx.success
      tx.failure
      val
    end
    expect(answer).to eq(42)
    expect(session.last_bookmark).to be nil
  end

  it 'rolls back write transaction when marked both success and failure' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    answer = session.write_transaction do |tx|
      val = tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
      tx.success
      tx.failure
      42
    end
    expect(answer).to eq(42)
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end


  it 'rolls back read transaction when marked success and throws exception' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    expect { 
      session.read_transaction do |tx|
        tx.run('RETURN 42').single[0]
        tx.success
        raise Neo4j::Driver::Exceptions::IllegalStateException
      end
    }.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    expect(session.last_bookmark).to be nil
  end

  it 'rolls back write transaction when marked success and exception is thrown' do
    session = driver.session
    expect(session.last_bookmark).to be nil
    expect {
      session.write_transaction do |tx|
        tx.run("CREATE (:Person {name: 'Natasha Romanoff'})")
        tx.success
        raise Neo4j::Driver::Exceptions::IllegalStateException
      end
    }.to raise_error Neo4j::Driver::Exceptions::IllegalStateException
    val = driver.session do |session|
      session.run("MATCH (p:Person {name: 'Natasha Romanoff'}) RETURN count(p)").single[0]
    end
    expect(val).to eq(0)
  end

  # it 'transactionRunShouldFailOnDeadlocks' do

  # end

  # it 'writeTransactionFunctionShouldRetryDeadlocks' do

  # end

  # it 'shouldExecuteTransactionWorkInCallerThread' do

  # end

  it 'should propagate failure when closed' do
    session = driver.session
    session.run('RETURN 10 / 0')
    expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
  end

  it 'should Propagate Pull All Failure When Closed' do
    session = driver.session
    session.run('UNWIND range(20000, 0, -1) AS x RETURN 10 / x')
    expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
  end


  it 'should Be Possible To Consume Result After Session Is Closed' do
    session = driver.session
    result = session.run('UNWIND range(1, 20000) AS x RETURN x').list.collect {|l| l['x']}
    expect(result.size).to eq(20000)
  end

  it 'should Propagate Failure From Summary' do
    session = driver.session
    result = session.run( "RETURN Wrong" )
    expect { result.summary }.to raise_error Neo4j::Driver::Exceptions::ClientException
  end

  it 'should Throw From Close When Previous Error Not Consumed' do
    session = driver.session
    session.run('CREATE ()')
    session.run('CREATE ()')
    session.run( 'RETURN 10 / 0')
    expect { session.close }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
  end

  it 'should Throw From Run When Previous Error Not Consumed' do
    session = driver.session
    session.run('CREATE ()')
    session.run('CREATE ()')
    session.run( 'RETURN 10 / 0')
    expect { session.run('CREATE ()') }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
  end

  def test_read_transaction(mode)
    driver.session do |session|
      session.run("CREATE (:Person {name: 'Tony Stark'})").consume
      session.run("CREATE (:Person {name: 'Steve Rogers'})").consume
    end
    driver.session(mode) do |session|
      names = session.read_transaction do |tx|
        tx.run('MATCH (p:Person) RETURN p.name AS name').collect do |result|
          result['name']
        end
      end
      expect(names).to contain_exactly('Tony Stark', 'Steve Rogers')
    end
  end

  def test_write_transaction(mode)
    driver.session(mode) do |session|
      session.write_transaction do |tx|
        node = tx.run("CREATE (s:Shield {material: 'Vibranium'}) RETURN s").next['s']
        expect(node.properties[:material]).to eq ('Vibranium')
      end
    end
    driver.session do |session|
      result = session.run('MATCH (s:Shield) RETURN s.material').next
      expect(result['s.material']).to eq('Vibranium')
    end
  end

  def test_tx_rollback_when_function_throws_exception(mode)
    driver.session(mode) do |session|
      expect {
        session.write_transaction do |tx|
          tx.run("CREATE (:Person {name: 'Thanos'})")
          tx.run('UNWIND range(0, 1) AS i RETURN 10/i')
          tx.success
        end
      }.to raise_error Neo4j::Driver::Exceptions::ClientException, '/ by zero'
    end

    driver.session do |session|
      result = session.run("MATCH (p:Person {name: 'Thanos'}) RETURN count(p)").next
      expect(result['count(p)']).to be_zero
    end
  end
end
